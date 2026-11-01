<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateItemRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $data = [];
        if ($this->has('nome')) {
            $data['nome'] = trim((string) $this->input('nome'));
        }
        if ($this->has('medida')) {
            $data['medida'] = mb_strtolower(trim((string) $this->input('medida')));
        }
        if ($data !== []) {
            $this->merge($data);
        }
    }

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nome' => ['sometimes', 'required', 'string', 'max:120'],
            'quantidade' => ['sometimes', 'required', 'integer', 'min:1'],
            'medida' => ['sometimes', 'required', 'string', 'in:un,g,kg,ml,l'],
            'preco' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'comprado' => ['sometimes', 'boolean'],
        ];
    }
}
