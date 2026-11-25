import { useEffect } from 'react';
import verificationService from '../services/verification/verificationService';
import { useStore } from '../store/store';

export const useDataVerification = () => {
  const { addNotification } = useStore();

  useEffect(() => {
    // Verificar integridad al iniciar
    const checkIntegrity = () => {
      const result = verificationService.verifyDataIntegrity();
      
      if (!result.isValid) {
        addNotification({
          type: 'warning',
          message: `Se encontraron ${result.errors.length} problemas de integridad`
        });
        
        console.warn('Data integrity issues:', result.errors);
      }
      
      if (result.warnings.length > 0) {
        console.info('Data warnings:', result.warnings);
      }
    };

    // Verificar inmediatamente
    checkIntegrity();

    // Verificar cada 5 minutos
    const interval = setInterval(checkIntegrity, 5 * 60 * 1000);

    return () => clearInterval(interval);
  }, [addNotification]);
};

export default useDataVerification;