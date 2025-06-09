using MessagePack;

namespace NetForge.Shared.Network.Packet.Serverbound.Authentication;

[MessagePackObject]
public class C2SLoginResponsePacket : BasePacket
{
	public override PacketId Id => PacketId.C2SLoginResponsePacket;

	[Key(0)]
	public int ProtocolNumber { get; set; } = -1;

	[Key(1)]
	public string Username { get; set; } = string.Empty;
	
	public C2SLoginResponsePacket() { }

	public C2SLoginResponsePacket(int protocolNumber, string username)
	{
		Username = username;
		ProtocolNumber = protocolNumber;
	}
}