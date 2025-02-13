export type DatabaseScriptability = "None" | "Custom" | "Read" | "ReadWrite" | "Write"

export type DatabasePropertyTag =
	"Deprecated"
	| "Hidden"
	| "NotBrowsable"
	| "NotReplicated"
	| "NotScriptable"
	| "ReadOnly"
	| "WriteOnly"

export type DatabaseClassTag =
	"Deprecated"
	| "NotBrowsable"
	| "NotCreatable"
	| "NotReplicated"
	| "PlayerReplicated"
	| "Service"
	| "Settings"
	| "UserSettings"

export type DatabaseProperty = {
	--[=[
		The name of the property.
	]=]
	Name: string,
	--[=[
		The datatype of the property.

		For normal datatypes this will be a string such as `string`, `Color3`, ...

		For enums this will be a string formatted as `Enum.EnumName`.
	]=]
	Datatype: string,
	--[=[
		The scriptability of this property, meaning if it can be written / read at runtime.

		All properties are writable and readable in Lune even if scriptability is not.
	]=]
	Scriptability: DatabaseScriptability,
	--[=[
		Tags describing the property.

		These include information such as if the property can be replicated to players
		at runtime, if the property should be hidden in Roblox Studio, and more.
	]=]
	Tags: { DatabasePropertyTag },
}

export type DatabaseClass = {
	--[=[
		The name of the class.
	]=]
	Name: string,
	--[=[
		The superclass (parent class) of this class.

		May be nil if no parent class exists.
	]=]
	Superclass: string?,
	--[=[
		Known properties for this class.
	]=]
	Properties: { [string]: DatabaseProperty },
	--[=[
		Default values for properties of this class.

		Note that these default properties use Lune's built-in datatype
		userdatas, and that if there is a new datatype that Lune does
		not yet know about, it may be missing from this table.
	]=]
	DefaultProperties: { [string]: any },
	--[=[
		Tags describing the class.

		These include information such as if the class can be replicated
		to players at runtime, and top-level class categories.
	]=]
	Tags: { DatabaseClassTag },
}

export type DatabaseEnum = {
	--[=[
		The name of this enum, for example `PartType` or `UserInputState`.
	]=]
	Name: string,
	--[=[
		Members of this enum.

		Note that this is a direct map of name -> enum values,
		and does not actually use the EnumItem datatype itself.
	]=]
	Items: { [string]: number },
}

export type Database = {
	--[=[
		The current version of the reflection database.

		This will follow the format `x.y.z.w`, which most commonly looks something like `0.567.0.123456789`
	]=]
	Version: string,
	--[=[
		Retrieves a list of all currently known class names.
	]=]
	GetClassNames: (self: Database) -> { string },
	--[=[
		Retrieves a list of all currently known enum names.
	]=]
	GetEnumNames: (self: Database) -> { string },
	--[=[
		Gets a class with the exact given name, if one exists.
	]=]
	GetClass: (self: Database, name: string) -> DatabaseClass?,
	--[=[
		Gets an enum with the exact given name, if one exists.
	]=]
	GetEnum: (self: Database, name: string) -> DatabaseEnum?,
	--[=[
		Finds a class with the given name.

		This will use case-insensitive matching and ignore leading and trailing whitespace.
	]=]
	FindClass: (self: Database, name: string) -> DatabaseClass?,
	--[=[
		Finds an enum with the given name.

		This will use case-insensitive matching and ignore leading and trailing whitespace.
	]=]
	FindEnum: (self: Database, name: string) -> DatabaseEnum?,
}

type InstanceProperties = {
	Parent: Instance?,
	ClassName: string,
	Name: string,
	-- FIXME: This breaks intellisense, but we need some way to access
	-- instance properties without casting the entire instance to any...
	-- [string]: any,
}

type InstanceMetatable = {
	Clone: (self: Instance) -> Instance,
	Destroy: (self: Instance) -> (),
	ClearAllChildren: (self: Instance) -> (),

	GetChildren: (self: Instance) -> { Instance },
	GetDebugId: (self: Instance) -> string,
	GetDescendants: (self: Instance) -> { Instance },
	GetFullName: (self: Instance) -> string,

	FindFirstAncestor: (self: Instance, name: string) -> Instance?,
	FindFirstAncestorOfClass: (self: Instance, className: string) -> Instance?,
	FindFirstAncestorWhichIsA: (self: Instance, className: string) -> Instance?,
	FindFirstChild: (self: Instance, name: string, recursive: boolean?) -> Instance?,
	FindFirstChildOfClass: (self: Instance, className: string, recursive: boolean?) -> Instance?,
	FindFirstChildWhichIsA: (self: Instance, className: string, recursive: boolean?) -> Instance?,

	IsA: (self: Instance, className: string) -> boolean,
	IsAncestorOf: (self: Instance, descendant: Instance) -> boolean,
	IsDescendantOf: (self: Instance, ancestor: Instance) -> boolean,

	GetAttribute: (self: Instance, name: string) -> any,
	GetAttributes: (self: Instance) -> { [string]: any },
	SetAttribute: (self: Instance, name: string, value: any) -> (),

	GetTags: (self: Instance) -> { string },
	HasTag: (self: Instance, name: string) -> boolean,
	AddTag: (self: Instance, name: string) -> (),
	RemoveTag: (self: Instance, name: string) -> (),
}

export type Instance = typeof(setmetatable(
	(nil :: any) :: InstanceProperties,
	(nil :: any) :: { __index: InstanceMetatable }
))

export type DataModelProperties = {}
export type DataModelMetatable = {
	GetService: (self: DataModel, name: string) -> Instance,
	FindService: (self: DataModel, name: string) -> Instance?,
}

export type DataModel =
	Instance
	& typeof(setmetatable(
		(nil :: any) :: DataModelProperties,
		(nil :: any) :: { __index: DataModelMetatable }
	))

return nil
