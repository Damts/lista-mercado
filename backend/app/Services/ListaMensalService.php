<?php

namespace App\Services;

use App\Models\Casa;
use App\Models\Lista;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

class ListaMensalService
{
    public function current(Casa $casa): Lista
    {
        $now = CarbonImmutable::now('America/Sao_Paulo');

        return $this->forMonth($casa, $now->year, $now->month);
    }

    public function forMonth(Casa $casa, int $year, int $month): Lista
    {
        return DB::transaction(function () use ($casa, $year, $month): Lista {
            $existing = Lista::query()
                ->where('casa_id', $casa->id)
                ->where('ano', $year)
                ->where('mes', $month)
                ->lockForUpdate()
                ->first();

            if ($existing !== null) {
                return $existing;
            }

            Lista::query()
                ->where('casa_id', $casa->id)
                ->where(function ($query) use ($year, $month): void {
                    $query->where('ano', '<', $year)
                        ->orWhere(function ($query) use ($year, $month): void {
                            $query->where('ano', $year)->where('mes', '<', $month);
                        });
                })
                ->whereNull('fechado_em')
                ->update(['fechado_em' => now()]);

            return Lista::create(['casa_id' => $casa->id, 'ano' => $year, 'mes' => $month]);
        });
    }
}
