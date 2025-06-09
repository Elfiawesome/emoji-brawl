using System.Collections.Generic;
using NetForge.Shared.Network.Packet;

namespace NetForge.Shared.Network;

// Helper handler class for packets for both server and clients
public class PacketHandler<Context>
{
	public delegate void BaseHandlerSignauture(BasePacket packet, Context? context);
	public delegate void ConcreteHandlerSignauture<TPacket>(TPacket packet, Context? context) where TPacket : BasePacket;
	public delegate void ConcreteContextlessHandlerSignauture<TPacket>(TPacket packet) where TPacket : BasePacket;


	private Dictionary<PacketId, BaseHandlerSignauture> _handlers = [];

	public Context? DefaultContext;

	public void Register<TPacket>(PacketId packetId, ConcreteHandlerSignauture<TPacket> handler) where TPacket : BasePacket
	{
		if (_handlers.ContainsKey(packetId)) { return; }

		_handlers[packetId] = (packet, context) =>
		{
			if (packet is TPacket concretPacket)
			{
				handler.Invoke(concretPacket, context);
			}
		};
	}

	public void Register<TPacket>(PacketId packetId, ConcreteContextlessHandlerSignauture<TPacket> handler) where TPacket : BasePacket
	{
		if (_handlers.ContainsKey(packetId)) { return; }

		_handlers[packetId] = (packet, _context) =>
		{
			if (packet is TPacket concretPacket)
			{
				handler.Invoke(concretPacket);
			}
		};
	}

	public void HandlePacket(BasePacket packet, Context context)
	{
		if (_handlers.TryGetValue(packet.Id, out var handler))
		{
			handler.Invoke(packet, context);
		}
	}

	public void HandlePacket(BasePacket packet)
	{
		if (_handlers.TryGetValue(packet.Id, out var handler))
		{
			handler.Invoke(packet, DefaultContext);
		}
	}
}
