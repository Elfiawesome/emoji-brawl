using System.Threading;
using NetForge.ServerCore.Game;
using NetForge.ServerCore.Network;
using NetForge.Shared.Debugging;

namespace NetForge.ServerCore;

public class Server
{
	private readonly CancellationTokenSource _serverCancellationTokenSource;
	public readonly CancellationToken _serverCancellationToken;
	public readonly GameService GameService;
	public readonly NetworkService NetworkService;

	public Server()
	{
		_serverCancellationTokenSource = new();
		_serverCancellationToken = _serverCancellationTokenSource.Token;

		NetworkService = new(_serverCancellationToken);
		GameService = new(_serverCancellationToken, NetworkService);
	}


	private void Wire()
	{
		NetworkService.PlayerConnectedEvent += GameService.OnPlayerJoined;
		NetworkService.PlayerDisconnectedEvent += GameService.OnPlayerLeft;
		NetworkService.PlayerPacketReceived += GameService.OnPlayerPacketReceived;
	}

	private void Unwire()
	{
		NetworkService.PlayerConnectedEvent -= GameService.OnPlayerJoined;
		NetworkService.PlayerDisconnectedEvent -= GameService.OnPlayerLeft;
		NetworkService.PlayerPacketReceived -= GameService.OnPlayerPacketReceived;		
	}

	public void Start()
	{
		Logger.Log("[Server] Starting server...");
		Wire();
		// Start all listeners
		NetworkService.StartListeners();
		GameService.Start();
		
	}

	public void Stop()
	{
		Logger.Log("[Server] Stopping server...");
		Unwire();
		NetworkService.StopListeners();
		GameService.Stop();
		_serverCancellationTokenSource.Cancel();
	}
}
