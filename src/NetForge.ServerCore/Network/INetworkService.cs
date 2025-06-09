
using NetForge.Shared;
using NetForge.Shared.Network.Packet;

namespace NetForge.ServerCore.Network;


public interface INetworkService
{
	public void PlayerHandlePacket<TPacket>(TPacket packet, PlayerId playerId) where TPacket : BasePacket;
}