using NetForge.Shared;

namespace NetForge.ServerCore.Game;

// The game representation of a player in the game. It will hold all global game player data and not much networking
public class Player
{
	public readonly PlayerId Id;

	public Player(PlayerId id)
	{
		Id = id;
	}
}