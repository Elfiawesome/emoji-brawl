
using System;
using System.Collections.Generic;
using System.Numerics;
using System.Threading;
using System.Threading.Tasks;
using NetForge.ServerCore.Network;
using NetForge.Shared;
using NetForge.Shared.Debugging;
using NetForge.Shared.Network.Packet;
using NetForge.Shared.Network.Packet.Clientbound.Game;

namespace NetForge.ServerCore.Game;

public class GameService
{
	private readonly CancellationTokenSource _CancellationTokenSource;
	private readonly CancellationToken _CancellationToken;
	private Task? _processTask;
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
		Random rnd = new Random();
		player.Positon = new Vector2(rnd.Next(0, 200), rnd.Next(0, 200));
		_players.Add(playerId, player);



		SendPacket(playerId, new S2CEnterMap());

		var _packet = new S2CUpdateEntities();
		foreach (var _playerItem in _players)
		{
			var _playerId = _playerItem.Key;
			var _player = _playerItem.Value;

			float[] floatPosition = new float[2];
			_player.Positon.CopyTo(floatPosition);
			_packet.Entities[_playerId] = (floatPosition, "player");
		}
		BroadcastPacket(playerId, _packet);
	}

	public void OnPlayerLeft(PlayerId playerId)
	{
		if (!_players.ContainsKey(playerId)) { return; }
		_players.Remove(playerId);
	}

	public void OnPlayerPacketReceived(PlayerId playerId, BasePacket packet)
	{

	}

	public void SendPacket<TPacket>(PlayerId playerId, TPacket packet) where TPacket : BasePacket
	{
		_network.PlayerHandlePacket(packet, playerId);
	}

	public void BroadcastPacket<TPacket>(PlayerId playerId, TPacket packet) where TPacket : BasePacket
	{
		foreach (var _playerItem in _players)
		{
			_network.PlayerHandlePacket(packet, _playerItem.Key);
		}
	}
}