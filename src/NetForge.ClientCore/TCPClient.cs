using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using NetForge.Shared.Debugging;
using NetForge.Shared.Network.Stream;

namespace NetForge.ClientCore;


public class TCPClient : BaseClient
{
	private readonly TcpClient _tcpClient;
	private PacketStream? _packetStream;
	private readonly CancellationTokenSource _clientCancellationTokenSource;
	private readonly CancellationToken _clientCancellationToken;
	private Task? _listeningTask;

	public TCPClient()
	{
		_clientCancellationTokenSource = new();
		_clientCancellationToken = _clientCancellationTokenSource.Token;

		_tcpClient = new();
	}

	public override void Connect(string ipAddressString, int port, string loginUsername = "DefaultUsername")
	{
		base.Connect(ipAddressString, port, loginUsername);
		try
		{
			IPAddress ipAddress = IPAddress.Parse(ipAddressString);
			IPEndPoint ipEndPoint = new IPEndPoint(ipAddress, port);
			_tcpClient.Connect(ipEndPoint);
			_packetStream = new PacketStream(_tcpClient.GetStream(), "Client");

			Logger.Log("[Client] Connecting to server");
			_listeningTask = Listen();
		}
		catch (Exception ex)
		{
			Logger.Log($"[Client] Error connecting to server: {ex.Message}");
			_clientCancellationTokenSource.Cancel();
			_tcpClient.Close();
			return;
		}
	}

	private async Task Listen()
	{
		while (!_clientCancellationToken.IsCancellationRequested)
		{
			try
			{
				if (_packetStream == null) { continue; }
				var packet = await _packetStream.GetPacketAsync(_clientCancellationToken);
				if (packet == null)
				{
					break;
				}
				HandlePacket(packet);
			}
			catch (Exception)
			{

			}
		}
		_tcpClient.Close();
	}

	public override void Leave()
	{
		_clientCancellationTokenSource.Cancel();
	}

	public override void SendPacket<TPacket>(TPacket packet)
	{
		if (_packetStream == null) { return; }
		_ = _packetStream.SendPacketAsync(packet);
	}
}

