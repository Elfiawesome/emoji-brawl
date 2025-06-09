using System.IO;
using MessagePack;

namespace NetForge.Shared.Network.Packet;

public enum PacketId : ushort
{
	TestPacket,
	S2CDisconnectPacket,
	S2CRequestLoginPacket,
	S2CLoginSuccessPacket,
	C2SLoginResponsePacket,

	S2CEnterMap,
}

[MessagePackObject]
public abstract class BasePacket
{
	public BasePacket() { }	

	[IgnoreMember]
	public abstract PacketId Id { get; }
}