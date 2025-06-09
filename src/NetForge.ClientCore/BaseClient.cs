using System;
using NetForge.Shared.Debugging;
using NetForge.Shared.Network.Packet;
using NetForge.Shared.Network.Packet.Clientbound.Authentication;
using NetForge.Shared.Network.Packet.Serverbound.Authentication;

namespace NetForge.ClientCore;

public class BaseClient
{
	public event Action<BasePacket> PacketReceivedEvent = delegate { };
	public readonly int ProtocolNumber = 1;
	protected bool _isAuthenticated = false;
	protected string _loginUsername = "DefaultUsername";

	public virtual void Connect(string ipAddressString, int port, string loginUsername = "DefaultUsername")
	{
		_loginUsername = loginUsername;
	}

	public virtual void Leave()
	{

	}

	public virtual void SendPacket<TPacket>(TPacket packet) where TPacket : BasePacket
	{

	}

	public void OnPacketReceived(BasePacket packet)
	{
		PacketReceivedEvent?.Invoke(packet);
	}

	public void HandlePacket<TPacket>(TPacket packet) where TPacket : BasePacket
	{
		if (packet is null)
		{
			Leave();
			return;
		}
		if (packet is S2CDisconnectPacket disconnectPacket)
		{
			Logger.Log($"[Client] Disconnected from server reason: {disconnectPacket.Reason}");
			Leave();
			return;
		}

		if (!_isAuthenticated)
		{
			// Handle authenticated packets
			if (packet is S2CRequestLoginPacket requestLoginPacket)
			{
				SendPacket(new C2SLoginResponsePacket(ProtocolNumber, _loginUsername));
			}
			if (packet is S2CLoginSuccessPacket successPacket)
			{
				_isAuthenticated = true;
				Logger.Log("[Client] Authentication successful");
			}
		}

		// Handle Packet as per normal
		OnPacketReceived(packet);
	}
}