USE NBG_V21
GO
/****** Object:  StoredProcedure [dbo].[PA_HD_WEB_RQ_Rechaza]    Script Date: 03/01/2023 16:50:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PA_WEB_RQ_Rechaza]
@p_CodCia as Smallint, @p_CodSuc as Smallint, @p_NumRQ as int, @p_CodUsr as int, @p_Motivo as varchar(200)
/***********************************************************************************************************
 Procedimiento	: PA_HD_WEB_RQ_Rechaza
 Proposito		: Ejecuta el RECHAZO del RQ en el nivel del usuario y marca el RQ como Rechazado
 Inputs			: p_CodCia, p_CodSuc, p_NumRQ, p_CodUsr, p_Motivo
 Se asume		: RQ existe en Tablas y Ya existe Validacion de acceso al RQ
 Efectos		: Retorno 1 registro con Indicacion de EXITO 1 o FALLO 0
 Retorno		: 1 Registro con 2 Columnas
 Notas			: N/A
 Modificaciones	: 
 Autor			: Narvasta Sergio
 Fecha y Hora	: 09/01/2023
***********************************************************************************************************/
AS
SET NOCOUNT ON

Declare @n_NumNiv Tinyint, @n_NivUsr Tinyint, @n_Item Tinyint
Declare @s_mensaje Varchar(200)
Set @n_Item   = 0
Set @n_NumNiv = 0

-- Identificar el Ultimo Nivel de Aprobacion de RQ
Select @n_NumNiv = COUNT(*) From REQ_APROB_REQCOM_ARC
where cia_codcia=@p_CodCia and rco_codepk=@p_NumRQ and arc_indapr=0
-- Si es UNO entonces es el ultimo nivel y se aprueba OC
If @@ERROR <> 0 
Begin
	Set @s_mensaje = 'Error al Consultar datos de los Niveles de RECHAZO de RQ ' + char(13) + ERROR_MESSAGE();
	Raiserror(@s_mensaje,16,1)
	Select -4 as Cod_Resultado, @s_Mensaje as Des_Resultado
	Return -4;
End

If @n_NumNiv<=0
Begin
   Set @s_mensaje = 'No hay niveles pendientes de RECHAZO de RQ '
   Select -3 as Cod_Resultado, @s_Mensaje as Des_Resultado
   Return -3;
End

Select @n_NivUsr = COUNT(*) from REQ_APROB_REQCOM_ARC
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ and uap_codepk=@p_CodUsr and arc_indapr=0
If Isnull(@n_NivUsr,0)<=0
Begin
   Set @s_mensaje = 'No hay niveles pendientes de RECHAZO de RQ para el USUARIO'
   Select 0 as Cod_Resultado, @s_Mensaje as Des_Resultado
   Return 0;
End
 
Begin Transaction APRUEBA

-- Aprobar en el nivel del Usuario
-- Select * From REQ_APROB_REQCOM_ARC
Update REQ_APROB_REQCOM_ARC Set arc_indapr=1
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ
and uap_codepk=@p_CodUsr and anm_codanm = 
(Select min(anm_codanm) from REQ_APROB_REQCOM_ARC 
 Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ and uap_codepk=@p_CodUsr and arc_indapr=0)
 
If @@ERROR <> 0 
Begin
	Set @s_mensaje = 'Error al RECHAZAR el requerimiento tabla REQ_APROB_REQCOM_ARC ' + char(13) + ERROR_MESSAGE();
	Raiserror(@s_mensaje,16,1)
	Rollback Transaction APRUEBA
	Select -2 as Cod_Resultado, @s_Mensaje as Des_Resultado
	Return -2;
End

-- Aprobar el RQ
-- 1 => Pendiente / 2 => Aprobado / 3 => Rechazado
Update REQ_REQUI_COMPRA_RCO Set rco_sitrco='3', usu_codapr=@p_CodUsr, rco_fecapr=getdate()
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ
   If @@ERROR <> 0 
   Begin
    	Set @s_mensaje = 'Error al RECHAZAR cabecera de REQUERIMIENTO REQUERIMIENTO_COMPRA_RCO ' + char(13) + ERROR_MESSAGE();
    	Raiserror(@s_mensaje,16,1)
    	Rollback Transaction APRUEBA
    	Select -1 as Cod_Resultado, @s_Mensaje as Des_Resultado
    	Return -1;
   End
Update REQ_REQUI_COMPRA_RCD Set rcd_Canapr=0
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ
   If @@ERROR <> 0 
   Begin
    	Set @s_mensaje = 'Error al RECHAZAR detalle de REQUERIMIENTO REQUERIMIENTO_COMPRA_RCD ' + char(13) + ERROR_MESSAGE();
    	Raiserror(@s_mensaje,16,1)
    	Rollback Transaction APRUEBA
    	Select -1 as Cod_Resultado, @s_Mensaje as Des_Resultado
    	Return -1;
   End				

-- Insertar Motivo de RECHAZO del RQ
SELECT @n_Item=MAX(mdr_secaci) from REQ_MOTIVO_DEVREQ_MDR Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ
Set @n_Item = isnull(@n_Item,0) + 1
INSERT INTO REQ_MOTIVO_DEVREQ_MDR(cia_codcia,suc_codsuc,rco_codepk,mdr_secaci,mdr_fecmdr,uap_codepk,mdr_tipmdr,mdr_motmdr,mdr_estado,mdr_usucre,mdr_feccre,mdr_usuact,mdr_fecact) 
Values (@p_CodCia,@p_CodSuc,@p_NumRQ,@n_Item,getdate(),@p_CodUsr,'0',@p_Motivo,'1',SYSTEM_USER,getdate(),SYSTEM_USER,getdate()) 
If @@ERROR <> 0 
Begin
  	Set @s_mensaje = 'Error al Insertar MOTIVO de RECHAZO MOTIVO_DEVREC_REQUIS_MDR' + char(13) + ERROR_MESSAGE();
  	Raiserror(@s_mensaje,16,1)
  	Rollback Transaction APRUEBA
   	Select -5 as Cod_Resultado, @s_Mensaje as Des_Resultado
   	Return -5;
End	
Commit Transaction APRUEBA
/*
Insert into COMPRAS_LOCALES_AUDITORIA_CLA (CIA_CODCIA, CLA_FECCLA, CLA_DESCLA, S10_CODUSU, CLA_MOTCLA, CLA_TIPCLA)
Values (@p_CodCia,GETDATE(),'RECHAZO DE LA REQUISICION: '+@p_NumRq,current_user,@p_Motivo,'R')
If @@ERROR <> 0 
Begin
  	Set @s_mensaje = 'Error al actualizar AUDITORIA de RECHAZO COMPRAS_LOCALES_AUDITORIA_CLA ' + char(13) + ERROR_MESSAGE();
  	Raiserror(@s_mensaje,16,1)
  	Rollback Transaction APRUEBA
   	Select -6 as Cod_Resultado, @s_Mensaje as Des_Resultado
   	Return -6;
End	



-- Enviar MAIL de RECHAZO
Exec PA_HD_WEB_RQ_Envio_Mail @p_CodCia=@p_CodCia, @p_CodSuc=@p_CodSuc, @p_NumRQ=@p_NumRQ, @p_TipAvi=1, @p_Motivo=@p_Motivo, @p_User_Envia=@p_CodUsr
If @@ERROR <> 0 
Begin
  	Set @s_mensaje = 'Error al enviar mail de RECHAZO ' + char(13) + ERROR_MESSAGE();
  	Raiserror(@s_mensaje,16,1)
  	Rollback Transaction APRUEBA
   	Select -7 as Cod_Resultado, @s_Mensaje as Des_Resultado
   	Return -7;
End				
*/
Select 1 as Cod_Resultado, 'RECHAZO EXITOSO' as Des_Resultado

Return

/*
Exec PA_HD_WEB_RQ_Rechaza @p_CodCia='01', @p_CodSuc='01', @p_NumRQ='2015010002', @p_CodUsr='AMADE'
--'CARRL7'
--'AMADE' 
*/

