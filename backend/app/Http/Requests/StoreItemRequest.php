<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreItemRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if ($this->has('nome')) {
            $this->merge(['nome' => trim((string) $this->input('nome'))]);
        }
    }

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nome' => ['required', 'string', 'max:120'],
            'quantidade' => ['required', 'integer', 'min:1'],
            'preco' => ['sometimes', 'nullable', 'numeric', 'min:0'],
        ];
    }
}
