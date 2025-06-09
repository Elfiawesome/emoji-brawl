using NetForge.Shared.Network;
using NetForge.Shared.Network.Packet;

namespace NetForge.ServerCore.Network.Connection;

public class IntegratedConnection : BaseConnection, IIntegratedPipe
{
	public IIntegratedPipe ?clientConnection;
	public void OnIntegratedPipeHandlePacket<TPacket>(TPacket packet) where TPacket : BasePacket
	{
		HandlePacket(packet);
	}

	public override void SendPacket<TPacket>(TPacket packet)
	{
		clientConnection?.OnIntegratedPipeHandlePacket(packet);
	}
}