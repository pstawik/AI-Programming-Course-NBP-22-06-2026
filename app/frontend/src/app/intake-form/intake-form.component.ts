import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-intake-form',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="intake-form-placeholder">
      <h2>Nowe zgłoszenie serwisowe</h2>
      <p>Formularz zgłoszenia — wkrótce dostępny.</p>
    </div>
  `,
  styles: [`
    .intake-form-placeholder {
      padding: 24px;
    }
  `]
})
export class IntakeFormComponent {}
