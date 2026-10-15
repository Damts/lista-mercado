# Lista Mercado — Flutter

Cliente Flutter/Dart 3.11 da API `/api/v1`.

## Executar

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Para Android emulator, use o endereço alcançável pelo dispositivo (por exemplo,
`10.0.2.2` no lugar de `127.0.0.1`). Em produção, informe uma URL HTTPS.

A sessão fica no `SharedPreferences`. Respostas 401 removem a sessão e o cache
de casas/itens; respostas 404 no contexto removem a casa ativa e seus itens
locais. Itens sempre são requisitados com `X-Casa-ID` da casa ativa.
