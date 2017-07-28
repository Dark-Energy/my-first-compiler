

FPUReg = array[0..7] of integer;
TYPE
  TItem = RECORD
     reg: integer;
  END;


PROCEDURE LoadF(num: PNode);
BEGIN
  CASE num.ntype OF
  END;
END;



PROCEDURE FloatExpr(e: PNode; var Item:TItem);
VAR
  x:TItem;
BEGIN
  IF isSimple(e.right) THEN begin
    FloatExpr(e.left);
  END
  ELSE IF isSimple(left) THEN begin
    FloatExpr(e.right);
    Reverse:= TRUE;
  END 
  ELSE begin
    FloatExpr(e.right); FloatExpr(e.left); Reverse:= TRUE;
  END;
END;



