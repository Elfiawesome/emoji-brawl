using MessagePack;

namespace NetForge.Shared.Network.Packet.Clientbound.Game;

[MessagePackObject]
public class S2CEnterMap : BasePacket
{
	public override PacketId Id => PacketId.S2CEnterMap;

	private int MapDataOrSomething;
}