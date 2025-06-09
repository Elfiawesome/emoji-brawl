
using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using NetForge.ServerCore.Network.Connection;
using NetForge.Shared.Debugging;

namespace NetForge.ServerCore.Network.Listener;

public class TCPListener : BaseListener
{
	private readonly TcpListener _tcpListener;
	private bool _isListening = false;

	public TCPListener(string addressString, int portNumber)
	{
		var iPAddress = IPAddress.Parse(addressString);
		_tcpListener = new(iPAddress, portNumber);
		_tcpListener.Start();
	}

	public override async Task Listen(CancellationToken serverCancellationToken)
	{
		_isListening = true;
		Logger.Log("[Server] [TCP Listener] started listening");
		while (!serverCancellationToken.IsCancellationRequested && _isListening)
		{
			try
			{
				TcpClient tcpClient = await _tcpListener.AcceptTcpClientAsync(serverCancellationToken);
				var tcpConnection = new TCPConnection(tcpClient, serverCancellationToken);
				OnNewConnection(tcpConnection);
			}
			catch (Exception ex)
			{
				// We will just continue trying to accept new connections even if there is an error on the listener
				Logger.Log($"[Server] [TCP Listener] error: {ex.Message}, continuing to listen...");
			}
		}
		Logger.Log("[Server] [TCP Listener] ended listening");
	}

	public override void Stop()
	{
		_isListening = false;
	}

}