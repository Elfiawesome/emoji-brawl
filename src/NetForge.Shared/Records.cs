using MessagePack;

namespace NetForge.Shared;

[MessagePackObject(true)] public record PlayerId(
	string Id
);