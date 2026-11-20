import React, { useEffect, useRef, useState } from 'react'
import {
  CheckCircleIcon,
  ClockIcon,
  CogIcon
} from '@/components/common/Icon'

interface FiscalProgressProps {
  isVisible: boolean
  onComplete: () => void
}

const steps = [
  {
    id: 1,
    text: 'Calculando impuestos y base imponible...',
    icon: CogIcon
  },
  {
    id: 2,
    text: 'Conectando con módulo fiscal SENIAT...',
    icon: ClockIcon
  },
  {
    id: 3,
    text: 'Asignando N.º de Factura y N.º de Control Fiscal...',
    icon: CheckCircleIcon
  }
]

const DURATION_MS = 2000

const FiscalProgress: React.FC<FiscalProgressProps> = ({
  isVisible,
  onComplete
}) => {
  const [currentStep, setCurrentStep] = useState(0)
  const [progress, setProgress] = useState(0)
  const onCompleteRef = useRef(onComplete)
  onCompleteRef.current = onComplete

  useEffect(() => {
    if (!isVisible) {
      setCurrentStep(0)
      setProgress(0)
      return
    }

    const startTime = Date.now()
    let completionTimeout: ReturnType<typeof setTimeout> | undefined
    const progressInterval = setInterval(() => {
      const elapsed = Math.min(Date.now() - startTime, DURATION_MS)
      const nextProgress = (elapsed / DURATION_MS) * 100
      const nextStep = Math.min(
        steps.length - 1,
        Math.floor((elapsed / DURATION_MS) * steps.length)
      )

      setProgress(nextProgress)
      setCurrentStep(nextStep)

      if (elapsed >= DURATION_MS) {
        clearInterval(progressInterval)
        completionTimeout = setTimeout(() => onCompleteRef.current(), 500)
      }
    }, 100)

    return () => {
      clearInterval(progressInterval)
      if (completionTimeout !== undefined) {
        clearTimeout(completionTimeout)
      }
    }
  }, [isVisible])

  if (!isVisible) return null

  const CurrentIcon = steps[currentStep].icon

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50"
      role="dialog"
      aria-modal="true"
      aria-labelledby="fiscal-progress-title"
      aria-describedby="fiscal-progress-description"
    >
      <div className="bg-gray-800 rounded-lg p-8 max-w-md w-full mx-4">
        <div className="text-center">
          <div className="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-blue-900 bg-opacity-20 mb-6">
            <CurrentIcon className="h-8 w-8 text-amalfi-turquoise animate-pulse" />
          </div>

          <h3
            id="fiscal-progress-title"
            className="text-lg font-medium text-white mb-2"
          >
            Simulación Fiscal SENIAT
          </h3>

          <p
            id="fiscal-progress-description"
            className="text-sm text-gray-300 mb-6"
            aria-live="polite"
          >
            {steps[currentStep].text}
          </p>

          <div
            className="w-full bg-gray-700 rounded-full h-2 mb-4"
            role="progressbar"
            aria-label="Progreso de la simulación fiscal"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={Math.round(progress)}
          >
            <div
              className="bg-amalfi-turquoise h-2 rounded-full transition-all duration-100 ease-out"
              style={{ width: `${progress}%` }}
            />
          </div>

          <div className="flex justify-between text-xs text-gray-400">
            {steps.map((step, index) => (
              <div key={step.id} className="flex flex-col items-center">
                <div className={`
                  w-6 h-6 rounded-full flex items-center justify-center mb-1
                  ${index <= currentStep
                    ? 'bg-amalfi-deep text-white'
                    : 'bg-gray-600 text-gray-400'
                  }
                `}>
                  {index + 1}
                </div>
                <span className="text-center max-w-20">
                  {step.text.split('...')[0]}
                </span>
              </div>
            ))}
          </div>

          <div className="mt-6 p-3 bg-yellow-900 bg-opacity-20 rounded-lg border border-yellow-700">
            <p className="text-xs text-yellow-300">
              <strong>IMPORTANTE:</strong> Esto es una simulación fiscal para
              fines de demostración. No genera documentos fiscales legalmente
              válidos ante el SENIAT.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default FiscalProgress
