<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\EntrarConviteRequest;
use App\Models\Casa;
use App\Models\Audit;
use App\Models\Convite;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ConviteController extends Controller
{
    private const CODE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

    public function store(Request $request, int $casa): JsonResponse
    {
        $casaModel = $this->memberHouse($request, $casa);
        $invite = DB::transaction(function () use ($casaModel): Convite {
            for ($attempt = 0; $attempt < 5; $attempt++) {
                $code = $this->generateCode();
                if (! Convite::where('codigo', $code)->exists()) {
                    return Convite::create([
                        'casa_id' => $casaModel->id,
                        'codigo' => $code,
                        'expira_em' => Carbon::now()->addDay(),
                    ]);
                }
            }

            throw new \RuntimeException('Não foi possível gerar um código de convite.');
        });
        Audit::record($request->user()->id, 'convite.created', Convite::class, $invite->id, $casaModel->id);

        return response()->json(['data' => [
            'id' => $invite->id,
            'codigo' => $invite->codigo,
            'expira_em' => $invite->expira_em,
        ]], 201);
    }

    public function revoke(Request $request, int $casa, int $convite): \Illuminate\Http\Response
    {
        $casaModel = $this->memberHouse($request, $casa);
        $invite = Convite::query()
            ->whereKey($convite)
            ->where('casa_id', $casaModel->id)
            ->firstOrFail();

        if ($invite->usado_em === null && $invite->revogado_em === null) {
            $invite->update(['revogado_em' => Carbon::now()]);
            Audit::record($request->user()->id, 'convite.revoked', Convite::class, $invite->id, $casaModel->id);
        }

        return response()->noContent();
    }

    public function join(EntrarConviteRequest $request): \Illuminate\Http\Response
    {
        DB::transaction(function () use ($request): void {
            $invite = Convite::query()
                ->where('codigo', $request->validated('codigo'))
                ->lockForUpdate()
                ->first();

            if ($invite === null || $invite->usado_em !== null || $invite->revogado_em !== null || $invite->expira_em->isPast()) {
                throw ValidationException::withMessages([
                    'codigo' => ['O convite é inválido, expirado, usado ou revogado.'],
                ])->status(422);
            }

            $pessoa = $request->user()->pessoa()->firstOrFail();
            if ($pessoa->casas()->whereKey($invite->casa_id)->exists()) {
                throw ValidationException::withMessages([
                    'codigo' => ['A conta já pertence a esta casa.'],
                ])->status(409);
            }

            $pessoa->casas()->attach($invite->casa_id);
            $invite->update([
                'usado_em' => Carbon::now(),
                'usado_por_pessoa_id' => $pessoa->id,
            ]);
            Audit::record($request->user()->id, 'convite.used', Convite::class, $invite->id, $invite->casa_id, [
                'pessoa_id' => $pessoa->id,
            ]);
        });

        return response()->noContent();
    }

    private function memberHouse(Request $request, int $casa): Casa
    {
        return Casa::query()
            ->whereKey($casa)
            ->whereHas('pessoas.user', fn ($query) => $query->whereKey($request->user()->id))
            ->firstOrFail();
    }

    private function generateCode(): string
    {
        $code = '';
        for ($index = 0; $index < 10; $index++) {
            $code .= self::CODE_ALPHABET[random_int(0, strlen(self::CODE_ALPHABET) - 1)];
        }

        return $code;
    }
}
