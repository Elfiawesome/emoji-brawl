using System.Collections.Generic;
using MessagePack;
using NetForge.Shared.Network.Packet.Clientbound.Authentication;
using NetForge.Shared.Network.Packet.Serverbound.Authentication;

namespace NetForge.Shared.Network.Packet;

public static class PacketFactory
{
	private delegate BasePacket DeserializerSignature(byte[] packetData);

	private static readonly Dictionary<PacketId, DeserializerSignature> _deserializeFactory = [];

	public static void Initialize()
	{
		Register<S2CDisconnectPacket>(PacketId.S2CDisconnectPacket);
		Register<S2CRequestLoginPacket>(PacketId.S2CRequestLoginPacket);
		Register<C2SLoginResponsePacket>(PacketId.C2SLoginResponsePacket);
		Register<S2CLoginSuccessPacket>(PacketId.S2CLoginSuccessPacket);
		Register<S2CEnterMap>(PacketId.S2CEnterMap);
	}

	public static void Register<TPacket>(PacketId packetId) where TPacket : BasePacket, new() // What does , new() mean or do?
	{
		if (_deserializeFactory.ContainsKey(packetId)) { return; }
		_deserializeFactory[packetId] = (byte[] packetData) =>
		{
			var packet = MessagePackSerializer.Deserialize<TPacket>(packetData);
			return packet;
		};
	}

	public static BasePacket? Deserialize(PacketId packetId, byte[] packetByte)
	{
		if (!_deserializeFactory.ContainsKey(packetId)) { return null; }

		BasePacket? packet = _deserializeFactory[packetId]?.Invoke(packetByte);
		return packet;
	}
}