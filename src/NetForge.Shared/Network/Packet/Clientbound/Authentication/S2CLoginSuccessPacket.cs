using MessagePack;

namespace NetForge.Shared.Network.Packet.Clientbound.Authentication;

[MessagePackObject]
public class S2CLoginSuccessPacket : BasePacket
{
	public override PacketId Id => PacketId.S2CLoginSuccessPacket;

	[Key(0)]
	public PlayerId PlayerId = new("null");

	public S2CLoginSuccessPacket()
	{
	}

	public S2CLoginSuccessPacket(PlayerId playerId)
	{
		PlayerId = playerId;
	}
}