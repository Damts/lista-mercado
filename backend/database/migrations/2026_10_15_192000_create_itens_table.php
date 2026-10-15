<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('itens', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('casa_id')->constrained('casas')->cascadeOnDelete();
            $table->string('nome', 120);
            $table->string('nome_normalizado', 120);
            $table->boolean('marcado')->default(false);
            $table->timestamps();
            $table->unique(['casa_id', 'nome_normalizado']);
            $table->index(['casa_id', 'marcado']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('itens');
    }
};
