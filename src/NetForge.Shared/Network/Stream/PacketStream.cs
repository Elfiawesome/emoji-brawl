using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using MessagePack;
using NetForge.Shared.Debugging;
using NetForge.Shared.Network.Packet;

namespace NetForge.Shared.Network.Stream;

public class PacketStream
{
	private string _dParentController = ""; // Remove when in production
	private readonly NetworkStream _stream;
	private static readonly Encoding _stringEncoding = Encoding.UTF8;

	// Size of the field that stores the total length of (PacketId + Packet Paylod). [2]
	const int PACKET_LENGTH_FIELD_SIZE = sizeof(int);
	// Size of the field that stores the PacketId [3]
	const int PACKET_ID_FIELD_SIZE = sizeof(ushort);
	// Max size for (PacketId + Payload) [2MB]
	const int MAX_PACKET_PAYLOAD_SIZE = 2 * 1024 * 1024;

	public PacketStream(NetworkStream stream, string dParentController = "None")
	{
		_stream = stream;
		_dParentController = dParentController;

	}


	public async Task<BasePacket?> GetPacketAsync(CancellationToken token)
	{
		try
		{
			// Read the total length of incoming packet (Id + Payload)
			var lengthBuffer = new byte[PACKET_LENGTH_FIELD_SIZE];
			int bytesRead = await ReadExactlyAsync(lengthBuffer, 0, PACKET_LENGTH_FIELD_SIZE, token);
			if (bytesRead == 0)
			{
				throw new Exception("Connection was closed while trying to read the total packet size");
			}
			if (bytesRead < PACKET_LENGTH_FIELD_SIZE)
			{
				throw new Exception("Incomplete Packet Field Size");
			}
			int totalPacketSize = BitConverter.ToInt32(lengthBuffer, 0);
			if (totalPacketSize <= 0 || totalPacketSize > MAX_PACKET_PAYLOAD_SIZE)
			{
				throw new Exception($"Received a invalid packet size of {totalPacketSize}. Max is {MAX_PACKET_PAYLOAD_SIZE}.");
			}

			// Reading the packet
			byte[] typeAndPayloadBuffer = new byte[totalPacketSize];
			bytesRead = await ReadExactlyAsync(typeAndPayloadBuffer, 0, totalPacketSize, token);
			if (bytesRead == 0)
			{
				throw new Exception("Connection was Closed while trying to read packet contents");
			}
			if (bytesRead < totalPacketSize)
			{
				throw new Exception("Incomplete Packet on Packet contents");
			}

			using (var ms = new MemoryStream(typeAndPayloadBuffer))
			{
				using (var br = new BinaryReader(ms, _stringEncoding))
				{
					// Get Packet Id
					if (ms.Length < PACKET_ID_FIELD_SIZE)
					{
						throw new Exception("Packet size is less than Id field size");
					}

					PacketId packetId = (PacketId)br.ReadUInt16();
					var packetData = br.ReadBytes((int)ms.Length - PACKET_ID_FIELD_SIZE);
					BasePacket? packet = PacketFactory.Deserialize(packetId, packetData);
					if (packet == null)
					{
						throw new Exception("Packet does not exist in registry");
					}
					return packet;
				}
			}
		}
		catch (Exception ex)
		{
			Logger.Log($"[{_dParentController}/PacketStream] Error while reading packet: {ex.Message}");
			return null;
		}
	}

	private async Task<int> ReadExactlyAsync(byte[] buffer, int offset, int count, CancellationToken token)
	{
		int totalBytesRead = 0;
		while (totalBytesRead < count)
		{
			int bytesRead = await _stream.ReadAsync(buffer, offset + totalBytesRead, count - totalBytesRead, token);
			if (bytesRead == 0) // Stream closed prematurely
			{
				return totalBytesRead; // Return what was read, could be 0
			}
			totalBytesRead += bytesRead;
		}
		return totalBytesRead;
	}

	public async Task SendPacketAsync<TPacket>(TPacket packet, CancellationToken token = default) where TPacket : BasePacket
	{
		try
		{
			using (var ms = new MemoryStream())
			{
				using (var bw = new BinaryWriter(ms, _stringEncoding, true))
				{
					// Packet Id
					bw.Write((ushort)packet.Id);
					// Packet Payload
					var packetData = MessagePackSerializer.Serialize(packet);
					bw.Write(packetData);
					bw.Flush();

					byte[] packetBuffer = ms.ToArray();
					if (packetBuffer.Length > MAX_PACKET_PAYLOAD_SIZE)
					{
						// Packet too big
						return;
					}

					// Get the length of (Type + Payload)
					var lengthBuffer = BitConverter.GetBytes(packetBuffer.Length);

					// Write to the network stream: Length, then (Type + Payload)
					await _stream.WriteAsync(lengthBuffer, 0, PACKET_LENGTH_FIELD_SIZE, token);
					await _stream.WriteAsync(packetBuffer, 0, packetBuffer.Length, token);
					await _stream.FlushAsync(token);
				}
			}
		}
		catch (Exception ex)
		{
			Logger.Log($"[{_dParentController}/PacketStream] Error while sending packet: {ex.Message}");
		}
	}
}