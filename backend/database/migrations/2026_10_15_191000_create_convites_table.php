<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('convites', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('casa_id')->constrained('casas')->cascadeOnDelete();
            $table->string('codigo', 10)->unique();
            $table->timestamp('expira_em');
            $table->timestamp('usado_em')->nullable();
            $table->timestamp('revogado_em')->nullable();
            $table->foreignId('usado_por_pessoa_id')->nullable()->constrained('pessoas')->nullOnDelete();
            $table->timestamps();
            $table->index(['casa_id', 'expira_em']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('convites');
    }
};
