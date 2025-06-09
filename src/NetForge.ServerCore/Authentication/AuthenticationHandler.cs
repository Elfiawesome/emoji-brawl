using NetForge.ServerCore.Network.Connection;
using NetForge.Shared;
using NetForge.Shared.Debugging;
using NetForge.Shared.Network.Packet;
using NetForge.Shared.Network.Packet.Clientbound.Authentication;
using NetForge.Shared.Network.Packet.Serverbound.Authentication;

namespace NetForge.ServerCore.Authentication;

public class AuthenticationHandler
{
	public void HandleConnection(BaseConnection connection)
	{
		Logger.Log($"[Server] [AuthenticationHandler] Handling a new Authentication Handshake");
		AttachConnectionToHandler(connection);
		connection.SendPacket(new S2CRequestLoginPacket());
	}

	private void OnConnectionPacketReceived(BaseConnection connection, BasePacket packet)
	{
		if (packet is C2SLoginResponsePacket loginResponsePacket)
		{
			var username = loginResponsePacket.Username;

			// Do our checks
			if (username == "")
			{
				connection.InitiateClose("Username cannot be empty.");
				return;
			}

			// Convert username to PlayerId
			PlayerId PlayerId = new(username);

			Logger.Log($"[Server] [AuthenticationHandler] Connection {PlayerId} authenticated successfully.");
			DetachConnectionFromHandler(connection);
			connection.OnConnectionAuthenticatedEvent(PlayerId);
		}
	}

	
	private void AttachConnectionToHandler(BaseConnection connection)
	{
		connection.PacketReceivedEvent += OnConnectionPacketReceived;
	}

	private void DetachConnectionFromHandler(BaseConnection connection)
	{
		connection.PacketReceivedEvent -= OnConnectionPacketReceived;
	}

}