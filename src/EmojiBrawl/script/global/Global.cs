using Godot;
using NetForge.Shared.Debugging;
using NetForge.Shared.Network.Packet;

public partial class Global : Node
{
	public string Username { get; private set; } = "DefaultUsername";
	public int InstanceNumber { get; private set; } = -1;

	public override void _Ready()
	{
		bootstrap();
		if (OS.IsDebugBuild())
		{
			setInstanceNumber();
			setWindow();
		}
		Username = $"ELFIAWESOME_{InstanceNumber}";
		GetWindow().Title = $"{Username} - Instance {InstanceNumber}";

		GD.Print("Global script is ready.");

	}
	private void setInstanceNumber()
	{
		var commandArgs = OS.GetCmdlineArgs();
		if (commandArgs.Length < 1) { return; }
		if (int.TryParse(commandArgs[1], out int instanceNumber))
		{
			InstanceNumber = instanceNumber;
		}
	}
	private void setWindow()
	{
		var screenSize = (Vector2)DisplayServer.ScreenGetUsableRect().Size;

		int titleBarHeight = 40;
		Vector2 startingPoint;
		switch (InstanceNumber)
		{
			case 0:
				startingPoint = new Vector2(0, 0);
				break;
			case 1:
				startingPoint = new Vector2(screenSize.X / 2, 0);
				break;
			case 2:
				startingPoint = new Vector2(0, screenSize.Y / 2);
				break;
			case 3:
				startingPoint = screenSize / 2;
				break;
			default:
				startingPoint = new Vector2(0, 0);
				break;
		}

		startingPoint.Y += titleBarHeight;
		GetWindow().Size = (Vector2I)(screenSize / 2);
		GetWindow().Size -= new Vector2I(0, titleBarHeight);
		GetWindow().Position = (Vector2I)startingPoint;
	}

	private void bootstrap()
	{
		Logger.MessageLoggedEvent += (message) => { GD.Print(message); };
		PacketFactory.Initialize();
	}
}