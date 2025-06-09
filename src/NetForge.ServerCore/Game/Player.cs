using System.Numerics;
using NetForge.Shared;

namespace NetForge.ServerCore.Game;

// The game representation of a player in the game. It will hold all global game player data and not much networking
public class Player
{
	public readonly PlayerId Id;

	public Vector2 Positon = Vector2.Zero;

	public Player(PlayerId id)
	{
		Id = id;


	}
}