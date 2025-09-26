import * as React from 'react'
import { clsx } from 'clsx'

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'secondary' | 'outline'
  size?: 'default' | 'icon'
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', size = 'default', ...props }, ref) => {
    const base = 'inline-flex items-center justify-center whitespace-nowrap font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 rounded-md'
    const variants = {
      default: 'bg-secondary text-secondary-foreground shadow-sm hover:bg-secondary/80',
      secondary: 'bg-secondary text-secondary-foreground shadow-sm hover:bg-secondary/80',
      outline: 'border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground',
    } as const
    const sizes = {
      default: 'h-8 px-3 text-xs',
      icon: 'h-9 w-9',
    } as const
    return (
      <button ref={ref} className={clsx(base, variants[variant], sizes[size], className)} {...props} />
    )
  }
)
Button.displayName = 'Button'
export default Button
