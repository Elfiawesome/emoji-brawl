using MessagePack;

namespace NetForge.Shared.Network.Packet.Clientbound.Authentication;

[MessagePackObject]
public class S2CRequestLoginPacket : BasePacket
{
	public override PacketId Id => PacketId.S2CRequestLoginPacket;

	[Key(0)]
	public string WelcomeMessage { get; set; } = "Hello!";
}