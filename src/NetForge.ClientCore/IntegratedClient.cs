using NetForge.Shared.Network;
using NetForge.Shared.Network.Packet;

namespace NetForge.ClientCore;

public class IntegratedClient : BaseClient, IIntegratedPipe
{
	public IIntegratedPipe ?serverConnection;

	public void OnIntegratedPipeHandlePacket<TPacket>(TPacket packet) where TPacket : BasePacket
	{
		HandlePacket(packet);
	}

	public override void SendPacket<TPacket>(TPacket packet)
	{
		serverConnection?.OnIntegratedPipeHandlePacket(packet);
	}
}