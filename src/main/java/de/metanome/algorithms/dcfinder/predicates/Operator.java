package de.metanome.algorithms.dcfinder.predicates;

public enum Operator {
  EQUAL, UNEQUAL, GREATER, LESS, GREATER_EQUAL, LESS_EQUAL;

  private Operator inverse;
  private Operator symmetric;
  private Operator[] implications;
  private Operator[] transitives;
  private String shortString;

  public Operator getInverse() {
    return inverse;
  }

  public Operator getSymmetric() {
    return symmetric;
  }

  public Operator[] getImplications() {
    return implications;
  }

  public String getShortString() {
    return shortString;
  }

  public Operator[] getTransitives() {
    return transitives;
  }

  /**
   * a {op} b iff ! (a {op.inverse} b)
   */
  static {
    EQUAL.inverse = UNEQUAL;
    UNEQUAL.inverse = EQUAL;
    GREATER.inverse = LESS_EQUAL;
    LESS.inverse = GREATER_EQUAL;
    GREATER_EQUAL.inverse = LESS;
    LESS_EQUAL.inverse = GREATER;
  }

  /**
   * a {op} b iff b {op.symmetric} a
   */
  static {
    EQUAL.symmetric = EQUAL;
    UNEQUAL.symmetric = UNEQUAL;
    GREATER.symmetric = LESS;
    LESS.symmetric = GREATER;
    GREATER_EQUAL.symmetric = LESS_EQUAL;
    LESS_EQUAL.symmetric = GREATER_EQUAL;
  }

  /**
   * if a {op} b, then a {op.implications} b
   */
  static {
    EQUAL.implications = new Operator[] {EQUAL, GREATER_EQUAL, LESS_EQUAL};
    UNEQUAL.implications = new Operator[] {UNEQUAL};
    GREATER.implications = new Operator[] {GREATER, GREATER_EQUAL, UNEQUAL};
    LESS.implications = new Operator[] {LESS, LESS_EQUAL, UNEQUAL};
    GREATER_EQUAL.implications = new Operator[] {GREATER_EQUAL};
    LESS_EQUAL.implications = new Operator[] {LESS_EQUAL};
  }

  /**
   * if a {op} b and b {op.transitives} c, then a {op} c
   */
  static {
    EQUAL.transitives = new Operator[] {EQUAL};
    UNEQUAL.transitives = new Operator[] {EQUAL};
    GREATER.transitives = new Operator[] {GREATER, GREATER_EQUAL, EQUAL};
    LESS.transitives = new Operator[] {LESS, LESS_EQUAL, EQUAL};
    GREATER_EQUAL.transitives = new Operator[] {GREATER, GREATER_EQUAL, EQUAL};
    LESS_EQUAL.transitives = new Operator[] {LESS, LESS_EQUAL, EQUAL};
  }

  /**
   * a short string that can be used in text output
   */
  static {
    EQUAL.shortString = "==";
    UNEQUAL.shortString = "<>";
    GREATER.shortString = ">";
    LESS.shortString = "<";
    GREATER_EQUAL.shortString = ">=";
    LESS_EQUAL.shortString = "<=";
  }

}