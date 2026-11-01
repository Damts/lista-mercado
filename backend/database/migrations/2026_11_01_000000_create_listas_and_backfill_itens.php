<?php

use Carbon\CarbonImmutable;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('listas', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('casa_id')->constrained('casas')->cascadeOnDelete();
            $table->unsignedSmallInteger('ano');
            $table->unsignedTinyInteger('mes');
            $table->timestamp('fechado_em')->nullable();
            $table->timestamps();
            $table->unique(['casa_id', 'ano', 'mes']);
        });

        Schema::table('itens', function (Blueprint $table): void {
            $table->foreignId('lista_id')->nullable()->after('casa_id')->constrained('listas')->cascadeOnDelete();
        });

        DB::transaction(function (): void {
            DB::table('itens')->orderBy('id')->each(function (object $item): void {
                $date = CarbonImmutable::parse($item->created_at)->setTimezone('America/Sao_Paulo');
                $lista = DB::table('listas')->where([
                    'casa_id' => $item->casa_id,
                    'ano' => $date->year,
                    'mes' => $date->month,
                ])->first();
                $listaId = $lista?->id ?? DB::table('listas')->insertGetId([
                    'casa_id' => $item->casa_id, 'ano' => $date->year, 'mes' => $date->month,
                    'created_at' => now(), 'updated_at' => now(),
                ]);
                DB::table('itens')->where('id', $item->id)->update(['lista_id' => $listaId]);
            });
        });

        Schema::table('itens', function (Blueprint $table): void {
            $table->dropUnique(['casa_id', 'nome_normalizado']);
            $table->unique(['lista_id', 'nome_normalizado']);
            $table->foreignId('lista_id')->nullable(false)->change();
        });
    }

    public function down(): void
    {
        Schema::table('itens', function (Blueprint $table): void {
            $table->dropUnique(['lista_id', 'nome_normalizado']);
            $table->dropConstrainedForeignId('lista_id');
            $table->unique(['casa_id', 'nome_normalizado']);
        });
        Schema::dropIfExists('listas');
    }
};
