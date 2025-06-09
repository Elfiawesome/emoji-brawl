using MessagePack;

namespace NetForge.Shared.Network.Packet.Clientbound.Authentication;

[MessagePackObject]
public class S2CEnterMap : BasePacket
{
	public override PacketId Id => PacketId.S2CEnterMap;

	private int MapDataOrSomething;
}