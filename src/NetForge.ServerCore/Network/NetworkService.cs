
using System;
using System.Collections.Generic;
using System.Threading;
using NetForge.ServerCore.Authentication;
using NetForge.ServerCore.Network.Connection;
using NetForge.ServerCore.Network.Listener;
using NetForge.Shared;
using NetForge.Shared.Network.Packet;

namespace NetForge.ServerCore.Network;

public class NetworkService : INetworkService
{
	public event Action<PlayerId> PlayerConnectedEvent = delegate { };
	public event Action<PlayerId> PlayerDisconnectedEvent = delegate { };
	public event Action<PlayerId, BasePacket> PlayerPacketReceived = delegate { };	


	public readonly int ProtocolNumber = 1;
	private readonly CancellationTokenSource _CancellationTokenSource;
	private readonly CancellationToken _CancellationToken;
	private readonly AuthenticationHandler _authenticationHandler = new();
	private readonly List<BaseListener> _listeners = [];
	private readonly Dictionary<PlayerId, BaseConnection> _connections = [];

	public NetworkService(CancellationToken _parentCancellationToken)
	{
		_CancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(_parentCancellationToken);
		_CancellationToken = _CancellationTokenSource.Token;
	}

	public void AddListener(BaseListener listener)
	{
		listener.NewConnectionEvent += OnNewConnection;
		_listeners.Add(listener);
	}

	public void RemoveListener(BaseListener listener)
	{
		listener.NewConnectionEvent -= OnNewConnection;
		_listeners.Remove(listener);
	}

	public void StartListeners()
	{
		foreach (var listener in _listeners)
		{
			listener.Listen(_CancellationToken);
		}
	}

	public void StopListeners()
	{
		foreach (var listener in _listeners) { listener.Stop(); }
		_CancellationTokenSource.Cancel();
	}

	public void ManualAddNewConnection(BaseConnection connection)
	{
		OnNewConnection(connection);
	}

	private void OnNewConnection(BaseConnection connection)
	{
		// Attach connection to myself
		connection.PacketReceivedEvent += OnPacketReceived;
		connection.ConnectionClosedEvent += OnConnectionClosed;
		// Attach connection authentication event to myself
		connection.ConnectionAuthenticatedEvent += OnConnectionAuthenticated;

		_authenticationHandler.HandleConnection(connection);
	}

	private void OnConnectionAuthenticated(BaseConnection connection, PlayerId id)
	{
		// Detach connection authentication event to myself
		connection.ConnectionAuthenticatedEvent -= OnConnectionAuthenticated;

		if (_connections.ContainsKey(id))
		{
			connection.InitiateClose("Connection already exists with this PlayerId.");
			return;
		}

		_connections[id] = connection;
		PlayerConnectedEvent.Invoke(id);
	}


	private void OnConnectionClosed(BaseConnection connection)
	{
		// Detach connection from myself
		connection.PacketReceivedEvent -= OnPacketReceived;
		connection.ConnectionClosedEvent -= OnConnectionClosed;

		// Need check if this event is still subscribed onto it because if it is closed after authentication, it will no longer be signal connected
		connection.ConnectionAuthenticatedEvent -= OnConnectionAuthenticated;

		if (connection.Id != null)
		{
			PlayerDisconnectedEvent.Invoke(connection.Id);
		}
	}


	private void OnPacketReceived(BaseConnection connection, BasePacket packet)
	{
		if (connection.Id == null) { return; }
		PlayerPacketReceived.Invoke(connection.Id, packet);
	}

	public void PlayerHandlePacket<TPacket>(TPacket packet, PlayerId playerId) where TPacket : BasePacket
	{
		_connections[playerId]?.SendPacket(packet);
	}
}