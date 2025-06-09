using System.Collections.Generic;
using System.Numerics;
using MessagePack;

namespace NetForge.Shared.Network.Packet.Clientbound.Game;

[MessagePackObject]
public class S2CUpdateEntities : BasePacket
{
	public override PacketId Id => PacketId.S2CUpdateEntities;

	[Key(0)]
	public Dictionary<PlayerId, (float[], string)> Entities = [];
}