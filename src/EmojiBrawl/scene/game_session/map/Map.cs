using Godot;
using NetForge.Shared;
using System.Collections.Generic;

public partial class Map : Node2D
{
	public Dictionary<PlayerId, Node2D> Entities = [];


	public void UpdateEntity(PlayerId EntityId, Vector2 Position)
	{
		if (!Entities.ContainsKey(EntityId))
		{
			CreateEntity(EntityId);
		}
		Entities[EntityId].SetPosition(Position);
	}

	public void CreateEntity(PlayerId EntityId)
	{
		if (!Entities.ContainsKey(EntityId))
		{
			var player = (Node2D)GD.Load<PackedScene>("res://scene/game_session/entities/player.tscn").Instantiate();
			AddChild(player);
			Entities[EntityId] = player;
		}
	}
}
