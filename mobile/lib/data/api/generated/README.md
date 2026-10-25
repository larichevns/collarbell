# Generated API client: do not edit

Everything in this folder except this README is generated from
`contracts/openapi.json`:

- swagger_parser writes the retrofit clients (`*/…_client.dart`) and the
  json_serializable models (`models/`), with the settings in
  `mobile/swagger_parser.yaml`;
- build_runner writes their `*.g.dart` parts, with the settings in
  `mobile/build.yaml`.

Hand edits are lost at the next generation, and CI fails when this folder
differs from a fresh one. After the contract changes, regenerate from the
repository root and commit the result:

```sh
sh mobile/tool/generate_api.sh
```

The app uses these classes only in the repositories
(`lib/features/*/*_repository.dart`), through `ApiClient.send`, which turns
every failure into `ApiException`. Screens never import this folder.
