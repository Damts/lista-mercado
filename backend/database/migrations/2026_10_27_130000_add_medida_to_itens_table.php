<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('itens', function (Blueprint $table): void {
            $table->string('medida', 3)->default('un')->after('quantidade');
        });
    }

    public function down(): void
    {
        Schema::table('itens', function (Blueprint $table): void {
            $table->dropColumn('medida');
        });
    }
};
