USE NBG_V21
GO
/****** Object:  StoredProcedure [dbo].[PA_HD_WEB_RQ_Aprueba]    Script Date: 03/01/2023 10:57:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PA_WEB_RQ_Aprueba]
@p_CodCia as Smallint, @p_CodSuc as Smallint, @p_NumRQ as int, @p_CodUsr as int
/***********************************************************************************************************
 Procedimiento	: PA_HD_WEB_RQ_Aprueba
 Proposito		: Ejecuta la Aprobacion del RQ en el nivel del usuario, si es el ultimo nivel se aprueba el RQ
 Inputs			: p_CodCia, p_CodSuc, p_NumRQ, p_CodUsr
 Se asume		: RQ existe en Tablas y Ya existe Validacion de acceso al RQ
 Efectos		: Retorno 1 registro con Indicacion de EXITO 1 o FALLO 0
 Retorno		: 1 Registro con 2 Columnas
 Notas			: N/A
 Modificaciones	: 
 Autor			: Narvasta Sergio
 Fecha y Hora	: 27/01/2023
***********************************************************************************************************/
AS
SET NOCOUNT ON

Declare @n_NumNiv Tinyint, @n_NivUsr Tinyint 
Declare @s_mensaje Varchar(200)
Set @n_NumNiv = 0

-- Identificar el Ultimo Nivel de Aprobacion de RQ
Select @n_NumNiv = COUNT(*) From REQ_APROB_REQCOM_ARC
where cia_codcia=@p_CodCia and rco_codepk=@p_NumRQ and arc_indapr=0
-- Si es UNO entonces es el ultimo nivel y se aprueba OC
If @@ERROR <> 0 
Begin
	Set @s_mensaje = 'Error al Consultar datos de los Niveles de APROBACION de RQ ' 
	Raiserror(@s_mensaje,16,1)
	Select -4 as Cod_Resultado, @s_Mensaje as Des_Resultado
	Return -4
End

If @n_NumNiv<=0
Begin
   Set @s_mensaje = 'NO hay niveles pendientes de APROBACION de RQ '
   Select -3 as Cod_Resultado, @s_Mensaje as Des_Resultado
   Return -3
End

Select @n_NivUsr = COUNT(*) from REQ_APROB_REQCOM_ARC
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ and uap_codepk=@p_CodUsr and arc_indapr=0
If Isnull(@n_NivUsr,0)<=0
Begin
   Set @s_mensaje = 'NO hay niveles pendientes de APROBACION de RQ para el USUARIO'
   Select 0 as Cod_Resultado, @s_Mensaje as Des_Resultado
   Return 0
End
 
Begin Transaction APRUEBA

-- Aprobar en el nivel del Usuario
-- Select * From APROBAC_REQCOM_APROBACIONES_ARA
Update REQ_APROB_REQCOM_ARC Set arc_indapr=1, arc_fecact=getdate(), arc_codusu=SYSTEM_USER 
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ
and uap_codepk=@p_CodUsr 
and anm_codanm = 
(Select min(anm_codanm) from REQ_APROB_REQCOM_ARC 
 Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ and uap_codepk=@p_CodUsr and arc_indapr=0)
and tac_codtac =  
(Select min(tac_codtac) from REQ_APROB_REQCOM_ARC
 Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ and uap_codepk=@p_CodUsr and arc_indapr=0)
 
If @@ERROR <> 0 
Begin
	Set @s_mensaje = 'Error al APROBAR el requerimiento tabla APROBAC_REQCOM_APROBACIONES_ARA ' 
	Raiserror(@s_mensaje,16,1)
	Rollback Transaction APRUEBA
	Select -2 as Cod_Resultado, @s_Mensaje as Des_Resultado
	Return -2
End

-- Aprobar el RQ
-- 1 => Pendiente / 2 => Aprobado / 3 => Rechazado
If @n_NumNiv=1
Begin
   Update REQ_REQUI_COMPRA_RCO Set rco_sitrco='2', uap_codepk=@p_CodUsr, rco_fecapr=getdate()
   Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ
   If @@ERROR <> 0 
   Begin
    	Set @s_mensaje = 'Error al APROBAR cabecera de REQUERIMIENTO REQUERIMIENTO_COMPRA_RCO ' 
    	Raiserror(@s_mensaje,16,1)
    	Rollback Transaction APRUEBA
    	Select -1 as Cod_Resultado, @s_Mensaje as Des_Resultado
    	Return -1
   End
   Update REQ_REQUI_COMPRA_RCD Set rcd_Canapr=rcd_canreq
   Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and rco_codepk=@p_NumRQ
   If @@ERROR <> 0 
   Begin
    	Set @s_mensaje = 'Error al APROBAR detalle de REQUERIMIENTO REQUERIMIENTO_COMPRA_RCD ' 
    	Raiserror(@s_mensaje,16,1)
    	Rollback Transaction APRUEBA
    	Select -1 as Cod_Resultado, @s_Mensaje as Des_Resultado
    	Return -1
   End				
End
/*
Insert into COMPRAS_LOCALES_AUDITORIA_CLA (CIA_CODCIA, CLA_FECCLA, CLA_DESCLA, S10_CODUSU, CLA_MOTCLA, CLA_TIPCLA,RCO_NUMRCO)
Values (@p_CodCia,GETDATE(),'APROBACION DE LA REQUISICION: '+@p_NumRq,current_user,'','R',@p_NumRQ)
If @@ERROR <> 0 
Begin
  	Set @s_mensaje = 'Error al actualizar AUDITORIA de APROBACION COMPRAS_LOCALES_AUDITORIA_CLA ' 
  	Raiserror(@s_mensaje,16,1)
  	Rollback Transaction APRUEBA
   	Select -5 as Cod_Resultado, @s_Mensaje as Des_Resultado
   	Return -5
End				

-- Enviar MAIL de APROBACION
if @n_NumNiv=1
Begin
   Exec PA_HD_WEB_RQ_Envio_Mail @p_CodCia=@p_CodCia, @p_CodSuc=@p_CodSuc, @p_NumRQ=@p_NumRQ, @p_TipAvi=3, @p_Motivo='', @p_User_Envia=@p_CodUsr
End   
Else
Begin
   Exec PA_HD_WEB_RQ_Envio_Mail @p_CodCia=@p_CodCia, @p_CodSuc=@p_CodSuc, @p_NumRQ=@p_NumRQ, @p_TipAvi=0, @p_Motivo='', @p_User_Envia=@p_CodUsr
End   
If @@ERROR <> 0 
Begin
  	Set @s_mensaje = 'Error al enviar mail de EVALUACION ' 
  	Raiserror(@s_mensaje,16,1)
  	Rollback Transaction APRUEBA
   	Select -7 as Cod_Resultado, @s_Mensaje as Des_Resultado
   	Return -7
End	
*/
Commit Transaction APRUEBA

Select 1 as Cod_Resultado, 'APROBACION EXITOSA' as Des_Resultado

Return

/*
Exec PA_HD_WEB_RQ_Aprueba @p_CodCia='01', @p_CodSuc='01', @p_NumRQ='RQ04031504', @p_CodUsr='CARRL7'
Exec PA_HD_WEB_RQ_Envio_Mail @p_CodCia='01', @p_CodSuc='01', @p_NumRQ='RQ04031504', @p_TipAvi=0, @p_Motivo='', @p_User_Envia='CARRL7'
--'CARRL7'
--'AMADE' 
*/


