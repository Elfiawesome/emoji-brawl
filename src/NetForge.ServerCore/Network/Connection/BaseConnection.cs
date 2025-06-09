using System;
using NetForge.Shared;
using NetForge.Shared.Network.Packet;
using NetForge.Shared.Network.Packet.Clientbound.Authentication;

namespace NetForge.ServerCore.Network.Connection;

public abstract class BaseConnection
{
	public event Action<BaseConnection> ConnectionClosedEvent = delegate { };
	public event Action<BaseConnection, PlayerId> ConnectionAuthenticatedEvent = delegate { };
	public event Action<BaseConnection, BasePacket> PacketReceivedEvent = delegate { };

	protected bool isClosedSignaled = false;

	public PlayerId? Id { get; protected set; } = null;

	public virtual void SendPacket<TPacket>(TPacket packet) where TPacket : BasePacket
	{
		// To be implemented by concrete connection classes
	}

	// Call this to INITIATE a close from server-side
	public virtual void InitiateClose(string disconnectReason)
	{
		if (isClosedSignaled) return;
		SendPacket(new S2CDisconnectPacket(disconnectReason));
		OnConnectionClosedEvent();
		isClosedSignaled = true;
	}

	public void OnConnectionClosedEvent()
	{
		ConnectionClosedEvent.Invoke(this);
	}

	public void OnConnectionAuthenticatedEvent(PlayerId playerId)
	{
		SendPacket(new S2CLoginSuccessPacket(playerId));
		Id = playerId;
		ConnectionAuthenticatedEvent.Invoke(this, playerId);
	}

	public void HandlePacket<TPacket>(TPacket packet) where TPacket : BasePacket
	{
		PacketReceivedEvent.Invoke(this, packet);
	}
}