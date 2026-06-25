import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-chat',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="chat-placeholder">
      <h2>Czat — asystent decyzji serwisowej</h2>
      <p>Widok czatu — wkrótce dostępny.</p>
    </div>
  `,
  styles: [`
    .chat-placeholder {
      padding: 24px;
    }
  `]
})
export class ChatComponent {}
