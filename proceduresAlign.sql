DROP PROCEDURE IF EXISTS SHIFTALIGN_PROC;
DROP PROCEDURE IF EXISTS SENDCODE_PROC;
DROP PROCEDURE IF EXISTS debug_msg;

DELIMITER ;;

/* debug_msg: just to debug */

DELIMITER ;;
CREATE PROCEDURE debug_msg(enabled INTEGER, msg VARCHAR(255))
BEGIN
  IF enabled THEN BEGIN
    select concat("** ", msg) AS '** DEBUG:';
  END; END IF;
END ;;
DELIMITER ;


/* SHIFTALIGN_PROC: get code and tries to align at least 90% of mutations
   - to know how many shift to align, in addition to avoiding infinite loop. initializes at -10 (shiftLimit variable) for shiftleft and goes up to 10 (while loop) for shiftright 
    posicao=uniprot position; AminBef=amino acid before mutation in uniprot; Position=position of node (PDB); Residue=amino acid of node (PDB) */
    
DELIMITER ;;
CREATE PROCEDURE SHIFTALIGN_PROC(inputCode VARCHAR(4))
BEGIN
  DECLARE notAlign boolean DEFAULT TRUE; 
  DECLARE shiftLimit INT DEFAULT -10;
  DECLARE qtdPositions INT; 
  DECLARE qtdNotAlign INT;

  call debug_msg(TRUE, CONCAT_WS('inputCode: ', inputCode));
  CREATE TABLE codeMutations as select distinct posicao, AminBef, Position,     Residue from MutationsPDBsWild_NodesDirect where code = inputCode;
  SET qtdPositions = (select count(distinct posicao) from codeMutations);
  WHILE (notAlign AND shiftLimit < 11) DO 
    SET qtdNotAlign = (select count(distinct m.posicao) from (select * from  codeMutations) m where m.aminBef != m.Residue);
    call debug_msg(TRUE, CONCAT_WS('on while. qtdNotAlign: ', qtdNotAlign));
    IF (qtdNotAlign > qtdPositions * 0.1) THEN 
      SET shiftLimit = shiftLimit + 1;
      call debug_msg(TRUE, CONCAT_WS('on if 1. shiftLimit: ', shiftLimit));
      update codeMutations u SET Residue = (select distinct Residue from Nodes where code = inputCode AND Position = posicao + shiftLimit limit 1); 
    ELSE
      SET notAlign = FALSE;
    END IF;
  END WHILE;
  IF (shiftLimit < 11) THEN
    UPDATE ToALIGN SET method = "Direct" where code = inputCode;
    UPDATE ToALIGN SET shifts = shiftLimit where code = inputCode;
    call debug_msg(TRUE, 'inside final if');     
  END IF;
DROP TABLE codeMutations;
END;
;;
DELIMITER ;


/* SENDCODE_PROC: sends to the alignment procedure the PDB codes that need to be aligned */

DELIMITER ;;
CREATE PROCEDURE SENDCODE_PROC()
BEGIN
  DECLARE s INT DEFAULT 0;
  DECLARE codeOutput VARCHAR(4);
  CREATE TABLE codes(select code from ToALIGN);
  ALTER TABLE codes ADD id INT NOT NULL AUTO_INCREMENT PRIMARY KEY;
  SET s = (select count(*) from codes);
  WHILE (s > 0) DO
    SET codeOutput = (select code from codes where id = s);
    call SHIFTDIRECTALIGN_PROC(codeOutput);
    SET s = s - 1;
  END WHILE;
DROP TABLE codes;
END;
;;
DELIMITER ;


call SENDCODE_PROC();
