using NetForge.Shared.Network.Packet;

namespace NetForge.Shared.Network;

public interface IIntegratedPipe
{
	public void OnIntegratedPipeHandlePacket<TPacket>(TPacket packet) where TPacket : BasePacket;
}