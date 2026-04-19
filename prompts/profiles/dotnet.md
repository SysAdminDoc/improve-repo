Stack: .NET (C# / WPF / WinForms / ASP.NET Core).

Prioritize:
- .NET 9 target (or .NET 8 LTS if long-term support matters); drop anything older
- Nullable reference types enabled (`<Nullable>enable</Nullable>`)
- `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` in Release
- C# 13 features: primary constructors, collection expressions, ref readonly
- MVVM pattern for WPF; `CommunityToolkit.Mvvm` for source-generated boilerplate
- Catppuccin/GitHub-Dark-like ResourceDictionary theming; don't rely on system chrome
- `async`/`await` all the way down; avoid `.Result` / `.Wait()` / `.GetAwaiter().GetResult()`
- `IAsyncEnumerable<T>` for streaming; `ValueTask<T>` for hot paths
- `HttpClientFactory` over `new HttpClient()` per call
- `Microsoft.Extensions.Logging` structured logging; no `Console.WriteLine`
- DI everywhere for testability; no `new Service()` inside business logic
- `dotnet publish -r win-x64 --self-contained true -p:PublishSingleFile=true` for single-exe delivery
- fo-dicom for DICOM work; SQLite or LiteDB for local persistence
- `Microsoft.Identity.Web` for auth; no homebrew OAuth
- CI: `dotnet test`, `dotnet format --verify-no-changes`, SBOM generation

Skip generic MVC suggestions — focus on stack-specific gaps in THIS project.
