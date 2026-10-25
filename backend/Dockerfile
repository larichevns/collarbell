# The API image for the server: deploy/compose.yml builds it from this folder.
# Packages are restored before the sources are copied, so a change in code doesn't download them again.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY global.json Directory.Build.props Directory.Packages.props ./
COPY src/Collarbell.Api/Collarbell.Api.csproj src/Collarbell.Api/
COPY src/Collarbell.ServiceDefaults/Collarbell.ServiceDefaults.csproj src/Collarbell.ServiceDefaults/
RUN dotnet restore src/Collarbell.Api/Collarbell.Api.csproj
COPY src/Collarbell.Api/ src/Collarbell.Api/
COPY src/Collarbell.ServiceDefaults/ src/Collarbell.ServiceDefaults/
# The OpenAPI contract is written by the normal build and checked in CI; the image doesn't need it.
RUN dotnet publish src/Collarbell.Api/Collarbell.Api.csproj -c Release -o /app --no-restore \
    -p:OpenApiGenerateDocuments=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
# The images' non-root user; the API listens on port 8080.
USER $APP_UID
ENTRYPOINT ["dotnet", "Collarbell.Api.dll"]
