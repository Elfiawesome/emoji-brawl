using MessagePack;

namespace NetForge.Shared.Network.Packet.Clientbound.Authentication;

[MessagePackObject]
public class S2CDisconnectPacket : BasePacket
{
	public override PacketId Id => PacketId.S2CDisconnectPacket;

	[Key(0)]
	public string Reason { get; set; } = string.Empty;

	public S2CDisconnectPacket() { }

	public S2CDisconnectPacket(string reason)
	{
		Reason = reason;
	}
}