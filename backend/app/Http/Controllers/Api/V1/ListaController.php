<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Casa;
use App\Models\Item;
use App\Models\Lista;
use App\Services\ListaMensalService;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;

class ListaController extends Controller
{
    private const PAGE_SIZE = 20;

    public function index(Request $request, int $casa, ListaMensalService $listas): JsonResponse
    {
        $house = $this->houseInContext($request, $casa);
        $listas->current($house);

        return response()->json(['data' => Lista::query()
            ->where('casa_id', $house->id)
            ->orderByDesc('ano')->orderByDesc('mes')->get()
            ->map(fn (Lista $lista): array => $this->listData($lista))->all()]);
    }

    public function store(Request $request, int $casa, ListaMensalService $listas): JsonResponse
    {
        $house = $this->houseInContext($request, $casa);
        $now = CarbonImmutable::now('America/Sao_Paulo');
        $exists = Lista::query()->where(['casa_id' => $house->id, 'ano' => $now->year, 'mes' => $now->month])->exists();
        $lista = $listas->current($house);

        return response()->json(['data' => $this->listData($lista)], $exists ? 200 : 201);
    }

    public function itens(Request $request, int $lista): JsonResponse
    {
        $list = Lista::query()->whereKey($lista)->where('casa_id', $this->context($request)->id)->firstOrFail();
        $comprado = $this->boughtFilter($request);
        $cursor = $this->decodeCursor($request->query('cursor'));
        $query = Item::query()->where('lista_id', $list->id)->orderByDesc('created_at')->orderByDesc('id');
        if ($comprado !== null) {
            $query->where('comprado', $comprado);
        }
        if ($cursor !== null) {
            $query->where(function ($query) use ($cursor): void {
                $query->where('created_at', '<', $cursor['created_at'])
                    ->orWhere(fn ($query) => $query->where('created_at', '=', $cursor['created_at'])->where('id', '<', $cursor['id']));
            });
        }
        $items = $query->limit(self::PAGE_SIZE + 1)->get();
        $hasMore = $items->count() > self::PAGE_SIZE;
        $page = $items->take(self::PAGE_SIZE)->values();
        $last = $page->last();

        return response()->json([
            'data' => $page->map(fn (Item $item): array => $this->itemData($item))->all(),
            'meta' => ['per_page' => self::PAGE_SIZE, 'has_more' => $hasMore,
                'next_cursor' => $hasMore && $last instanceof Item ? $this->encodeCursor($last) : null],
        ]);
    }

    public function copy(Request $request, int $destino, int $origem): Response
    {
        $house = $this->context($request);

        DB::transaction(function () use ($request, $house, $destino, $origem): void {
            $destination = Lista::query()->whereKey($destino)->where('casa_id', $house->id)->lockForUpdate()->firstOrFail();
            $origin = Lista::query()->whereKey($origem)->where('casa_id', $house->id)->lockForUpdate()->firstOrFail();

            if (Item::query()->where('lista_id', $destination->id)->exists()) {
                abort(response()->json([
                    'message' => 'A lista de destino já possui itens.',
                    'type' => 'conflict',
                    'error_code' => 'lista_nao_vazia',
                ], 409));
            }

            $expectedOrigin = Lista::query()
                ->where('casa_id', $house->id)
                ->where(function ($query) use ($destination): void {
                    $query->where('ano', '<', $destination->ano)
                        ->orWhere(fn ($query) => $query->where('ano', $destination->ano)->where('mes', '<', $destination->mes));
                })
                ->whereHas('itens')
                ->orderByDesc('ano')
                ->orderByDesc('mes')
                ->lockForUpdate()
                ->first();

            if ($expectedOrigin === null || $expectedOrigin->id !== $origin->id) {
                throw ValidationException::withMessages(['origem' => ['A origem não é a última lista com itens.']]);
            }

            $items = Item::query()->where('lista_id', $origin->id)->lockForUpdate()->get();
            foreach ($items as $item) {
                Item::create([
                    'casa_id' => $house->id,
                    'lista_id' => $destination->id,
                    'nome' => $item->nome,
                    'nome_normalizado' => $item->nome_normalizado,
                    'quantidade' => $item->quantidade,
                    'medida' => $item->medida,
                    'preco' => null,
                    'preco_anterior' => $item->preco,
                    'comprado' => false,
                ]);
            }

            \App\Models\Audit::record($request->user()->id, 'lista.items_copied', Lista::class, $destination->id, $house->id, [
                'origem_id' => $origin->id,
                'quantidade_itens' => $items->count(),
            ]);
        });

        return response()->noContent();
    }

    private function houseInContext(Request $request, int $id): Casa
    {
        return Casa::query()->whereKey($id)->whereKey($this->context($request)->id)->firstOrFail();
    }

    private function context(Request $request): Casa
    {
        return $request->attributes->get('casa');
    }

    private function boughtFilter(Request $request): ?bool
    {
        $value = $request->query('comprado');
        if ($value === null) return null;
        if (! in_array($value, ['true', 'false'], true)) {
            throw ValidationException::withMessages(['comprado' => ['O filtro comprado deve ser true ou false.']]);
        }
        return $value === 'true';
    }

    private function listData(Lista $lista): array
    {
        return ['id' => $lista->id, 'casa_id' => $lista->casa_id, 'ano' => $lista->ano, 'mes' => $lista->mes,
            'fechado_em' => $lista->fechado_em, 'created_at' => $lista->created_at, 'updated_at' => $lista->updated_at];
    }

    private function itemData(Item $item): array
    {
        return $item->only(['id', 'nome', 'quantidade', 'medida', 'preco', 'comprado', 'created_at', 'updated_at']);
    }

    private function encodeCursor(Item $item): string
    {
        return base64_encode(json_encode(['created_at' => $item->getRawOriginal('created_at'), 'id' => $item->id], JSON_THROW_ON_ERROR));
    }

    private function decodeCursor(?string $encoded): ?array
    {
        if ($encoded === null) return null;
        $decoded = base64_decode($encoded, true);
        $payload = $decoded === false ? null : json_decode($decoded, true);
        if (! is_array($payload) || ! isset($payload['created_at'], $payload['id']) || ! is_int($payload['id'])) {
            throw new BadRequestHttpException('Cursor inválido.');
        }
        try { $createdAt = CarbonImmutable::parse($payload['created_at'])->format('Y-m-d H:i:s'); }
        catch (\Throwable) { throw new BadRequestHttpException('Cursor inválido.'); }
        return ['created_at' => $createdAt, 'id' => $payload['id']];
    }
}
