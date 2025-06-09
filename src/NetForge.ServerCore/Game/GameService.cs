
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using NetForge.ServerCore.Network;
using NetForge.Shared;
using NetForge.Shared.Debugging;
using NetForge.Shared.Network.Packet;
using NetForge.Shared.Network.Packet.Clientbound.Authentication;

namespace NetForge.ServerCore.Game;

public class GameService
{
	private readonly CancellationTokenSource _CancellationTokenSource;
	private readonly CancellationToken _CancellationToken;
	private Task ?_processTask;
	private readonly Dictionary<PlayerId, Player> _players = [];
	public Dictionary<PlayerId, Player> Players { get => _players; }
	private INetworkService _network;

	public GameService(CancellationToken _parentCancellationToken, INetworkService networkService)
	{
		_CancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(_parentCancellationToken);
		_CancellationToken = _CancellationTokenSource.Token;

		_network = networkService;
	}


	public void Start()
	{
		Logger.Log("[GameService] Starting game service");
		_processTask = Process();
	}

	public void Stop()
	{
		Logger.Log("[GameService] Stopping game service");
		_CancellationTokenSource.Cancel();
	}

	private async Task Process()
	{
		Logger.Log("[GameService] Starting game service process...");
		while (!_CancellationToken.IsCancellationRequested)
		{
			try
			{
				await Task.Delay(1000);
			}
			catch (Exception)
			{

			}
		}
		Logger.Log("[GameService] Ended game service process.");
	}

	public void OnPlayerJoined(PlayerId playerId)
	{
		if (_players.ContainsKey(playerId)) { return; }
		var player = new Player(playerId);
		_players.Add(playerId, player);

		_network.PlayerHandlePacket(new S2CEnterMap(), playerId);
	}

	public void OnPlayerLeft(PlayerId playerId)
	{
		if (!_players.ContainsKey(playerId)) { return; }
		_players.Remove(playerId);
	}

	public void OnPlayerPacketReceived(PlayerId playerId, BasePacket packet)
	{

	}
}