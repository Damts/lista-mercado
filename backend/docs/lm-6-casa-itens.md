# LM-6 — contrato de leitura da casa e itens

Base: `/api/v1`, autenticação Bearer obrigatória.

## Contexto da casa

As rotas de itens exigem o header `X-Casa-ID`. O valor precisa ser uma casa à
qual o usuário autenticado pertence.

### `GET /casa-atual`

Headers:

```http
Authorization: Bearer <token>
X-Casa-ID: 12
Accept: application/json
```

Resposta `200`:

```json
{
  "data": {
    "id": 12,
    "nome": "Casa principal",
    "created_at": "2026-10-20T12:00:00.000000Z"
  }
}
```

## Lista de itens

### `GET /itens`

Headers: os mesmos de `GET /casa-atual`.

Resposta `200` com itens:

```json
{
  "data": [
    {
      "id": 31,
      "nome": "Leite",
      "marcado": false,
      "created_at": "2026-10-20T12:01:00.000000Z",
      "updated_at": "2026-10-20T12:01:00.000000Z"
    }
  ]
}
```

Resposta `200` vazia:

```json
{ "data": [] }
```

A ordenação é por `marcado` e depois por `id` ascendente. Não há paginação
nesta versão do contrato.

## Erros consumíveis pelo frontend

Todos os erros de API possuem `message`, `type` e `error_code`.

Header ausente — `400`:

```json
{
  "message": "O header X-Casa-ID é obrigatório.",
  "type": "house_context_required",
  "error_code": "house_context_required"
}
```

Casa inexistente ou sem vínculo — `404`:

```json
{
  "message": "Recurso não encontrado.",
  "type": "not_found",
  "error_code": "house_not_found"
}
```

A resposta `404` não inclui nome da casa nem itens.

## Campos garantidos para a tela

- Casa: `id`, `nome`, `created_at`.
- Item: `id`, `nome`, `marcado`, `created_at`, `updated_at`.
- Não existe campo de data de compra ou vencimento no contrato atual.
