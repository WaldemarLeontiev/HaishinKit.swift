import Foundation

public protocol TSReaderDelegate: class {
    func didReadPacketizedElementaryStream(_ data: ElementaryStreamSpecificData, PES: PacketizedElementaryStream)
}

// MARK: -
public class TSReader {
    public weak var delegate: TSReaderDelegate?

    private(set) var PAT: ProgramAssociationSpecific? {
        didSet {
            guard let PAT: ProgramAssociationSpecific = PAT else {
                return
            }
            for (channel, PID) in PAT.programs {
                dictionaryForPrograms[PID] = channel
            }
        }
    }
    private(set) var PMT: [UInt16: ProgramMapSpecific] = [: ] {
        didSet {
            for (_, pmt) in PMT {
                for data in pmt.elementaryStreamSpecificData {
                    dictionaryForESSpecData[data.elementaryPID] = data
                }
            }
        }
    }
    private(set) var numberOfPackets: Int = 0

    private var eof: UInt64 = 0
    private var cursor: Int = 0
    private var fileHandle: FileHandle?
    private var dictionaryForPrograms: [UInt16: UInt16] = [: ]
    private var dictionaryForESSpecData: [UInt16: ElementaryStreamSpecificData] = [: ]
    private var packetizedElementaryStreams: [UInt16: PacketizedElementaryStream] = [: ]

    public init(url: URL) throws {
        fileHandle = try FileHandle(forReadingFrom: url)
        eof = fileHandle!.seekToEndOfFile()
    }

    public func read(completion: () -> Void) {
        while let packet: TSPacket = next() {
            numberOfPackets += 1
            if packet.PID == 0x0000 {
                PAT = ProgramAssociationSpecific(packet.payload)
                continue
            }
            if let channel: UInt16 = dictionaryForPrograms[packet.PID] {
                PMT[channel] = ProgramMapSpecific(packet.payload)
                continue
            }
            if let data: ElementaryStreamSpecificData = dictionaryForESSpecData[packet.PID] {
                readPacketizedElementaryStream(data, packet: packet)
            }
        }
        completion()
    }

    func readPacketizedElementaryStream(_ data: ElementaryStreamSpecificData, packet: TSPacket) {
        if packet.payloadUnitStartIndicator {
            if let PES: PacketizedElementaryStream = packetizedElementaryStreams[packet.PID] {
                delegate?.didReadPacketizedElementaryStream(data, PES: PES)
            }
            packetizedElementaryStreams[packet.PID] = PacketizedElementaryStream(packet.payload)
            return
        }
        _ = packetizedElementaryStreams[packet.PID]?.append(packet.payload)
    }

    func close() {
        fileHandle?.closeFile()
    }
}

extension TSReader: IteratorProtocol {
    // MARK: IteratorProtocol
    public func next() -> TSPacket? {
        guard let fileHandle = fileHandle, UInt64(cursor * TSPacket.size) < eof else {
            return nil
        }
        defer {
            cursor += 1
        }
        fileHandle.seek(toFileOffset: UInt64(cursor * TSPacket.size))
        return TSPacket(data: fileHandle.readData(ofLength: TSPacket.size))
    }
}

extension TSReader: CustomStringConvertible {
    // MARK: CustomStringConvertible
    public var description: String {
        return Mirror(reflecting: self).description
    }
}
