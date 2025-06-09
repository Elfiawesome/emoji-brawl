
using System;
using System.Threading;
using System.Threading.Tasks;
using NetForge.ServerCore.Network.Connection;

namespace NetForge.ServerCore.Network.Listener;

public abstract class BaseListener
{
	public event Action<BaseConnection> NewConnectionEvent = delegate { };
	public abstract Task Listen(CancellationToken serverCancellationToken);
	public abstract void Stop();

	public void OnNewConnection(BaseConnection connection)
	{
		NewConnectionEvent(connection);
	}
}