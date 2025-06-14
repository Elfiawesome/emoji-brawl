using System;
using Godot;
using NetForge.ClientCore;
using NetForge.ServerCore;
using NetForge.ServerCore.Network.Connection;
using NetForge.ServerCore.Network.Listener;
using NetForge.Shared.Network;
using NetForge.Shared.Network.Packet;
using NetForge.Shared.Network.Packet.Clientbound.Game;

public partial class GameSession : Node2D
{
	public BaseClient? Client;
	public Server? IntegratedServer;
	private Map ?CurrentMap;

	private PacketHandler<int> _packetHandler = new();

	public override void _Ready()
	{
		RegisterHandlers();

		if (GetTree().Root.GetNode<Global>("/root/Global").InstanceNumber == 0)
		{
			StartIntegratedServer();
		}
		else
		{
			JoinServer();
		}

	}

	private void RegisterHandlers()
	{
		_packetHandler.Register<S2CEnterMap>(PacketId.S2CEnterMap, OnEnterMap);
		_packetHandler.Register<S2CUpdateEntities>(PacketId.S2CUpdateEntities, OnUpdateEntities);
	}

	public void JoinServer()
	{
		Client = new TCPClient();
		Client.Connect("127.0.0.1", 3115, GetTree().Root.GetNode<Global>("/root/Global").Username);
		Client.PacketReceivedEvent += _packetHandler.HandlePacket;
	}

	public void StartIntegratedServer()
	{
		// Start server
		IntegratedServer = new Server();
		IntegratedServer.NetworkService.AddListener(new TCPListener("127.0.0.1", 3115));
		IntegratedServer.Start();

		var integratedClient = new IntegratedClient();
		var integratedConnection = new IntegratedConnection();
		integratedClient.serverConnection = integratedConnection;
		integratedConnection.clientConnection = integratedClient;

		Client = integratedClient;
		Client.PacketReceivedEvent += _packetHandler.HandlePacket;

		integratedClient.Connect("", 0, GetTree().Root.GetNode<Global>("/root/Global").Username);
		IntegratedServer.NetworkService.ManualAddNewConnection(integratedConnection);
	}
	private void OnEnterMap(S2CEnterMap packet)
	{
		GD.Print("Ok i need to create a map now...");
		var mapScene = GD.Load<PackedScene>("res://scene/game_session/map/map.tscn");
		var map = (Map)mapScene.Instantiate();
		AddChild(map);
		CurrentMap = map;
	}

	private void OnUpdateEntities(S2CUpdateEntities packet)
	{
		if (CurrentMap == null) { return; }
		
		foreach (var entityItem in packet.Entities)
		{
			var entityData = entityItem.Value;
			var position = entityData.Item1;
			CurrentMap.UpdateEntity(entityItem.Key, new Vector2(position[0], position[1]));
		}
	}
}
