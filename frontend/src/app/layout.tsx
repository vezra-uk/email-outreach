// frontend/src/app/layout.tsx
import './globals.css'
import Header from '../components/header'
import { AuthProvider } from '../contexts/AuthContext'

export const metadata = {
  title: 'Email Automation System',
  description: 'Cold email automation with AI personalization',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <AuthProvider>
          <Header />
          <main>
            {children}
          </main>
        </AuthProvider>
      </body>
    </html>
  )
}