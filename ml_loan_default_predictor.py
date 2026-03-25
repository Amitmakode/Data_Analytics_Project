# ============================================================
# ML LOAN DEFAULT (NPA) PREDICTOR
# Banking Analytics Project — Phase 5
# ============================================================
# Step 1: Install libraries
#   pip install scikit-learn xgboost imbalanced-learn sqlalchemy pymysql joblib pandas
# Step 2: Update DB_CONFIG with your MySQL credentials
# Step 3: Run: python ml_loan_default_predictor.py
# ============================================================

import pandas as pd
import numpy as np
import warnings
import os
warnings.filterwarnings('ignore')

from sqlalchemy import create_engine, text
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (classification_report, confusion_matrix,
                             roc_auc_score, average_precision_score)
from xgboost import XGBClassifier
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline as ImbPipeline
import joblib

# ─────────────────────────────────────────────────────────────
# STEP 1 — DB CONFIG (update these)
# ─────────────────────────────────────────────────────────────
DB_CONFIG = {
    'host':     'localhost',
    'port':     3306,
    'user':     'root',         # your MySQL username
    'password': '12345', # your MySQL password
    'database': 'banking_analytics1'
}

def get_engine():
    url = (f"mysql+pymysql://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
           f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
    return create_engine(url)

# ─────────────────────────────────────────────────────────────
# STEP 2 — LOAD DATA
# ─────────────────────────────────────────────────────────────
def load_data(engine):
    print("\n[1/10] Loading data from MySQL...")
    query = """
        SELECT
            l.loan_id,
            l.customer_id,
            l.loan_type,
            l.principal_amount,
            l.interest_rate,
            l.tenure_months,
            l.emi_amount,
            l.outstanding_amount,
            l.overdue_days,
            l.overdue_amount,
            l.loan_status,
            l.credit_score_at_disbursement,
            l.collateral_type,
            c.age,
            c.monthly_income,
            c.credit_score,
            c.occupation,
            c.gender
        FROM loans l
        JOIN customers c ON l.customer_id = c.customer_id
    """
    df = pd.read_sql(query, engine)
    print(f"    Loaded {len(df)} loans")
    return df

# ─────────────────────────────────────────────────────────────
# STEP 3 — FEATURE ENGINEERING
# ─────────────────────────────────────────────────────────────
def engineer_features(df):
    print("\n[2/10] Engineering features...")

    # Target variable
    df['is_default'] = (df['loan_status'] == 'NPA').astype(int)

    # Derived ratios
    df['dti_ratio']         = df['emi_amount'] / df['monthly_income'].clip(lower=1)
    df['lti_ratio']         = df['principal_amount'] / df['monthly_income'].clip(lower=1)
    df['repayment_pct']     = ((df['principal_amount'] - df['outstanding_amount'])
                                / df['principal_amount'].clip(lower=1)) * 100
    df['credit_score_drop'] = df['credit_score_at_disbursement'] - df['credit_score']
    df['collateral_flag']   = df['collateral_type'].notna().astype(int)
    df['overdue_ratio']     = df['overdue_amount'] / df['principal_amount'].clip(lower=1)

    # Encode categoricals
    df['loan_type_enc']  = pd.Categorical(df['loan_type']).codes
    df['occupation_enc'] = pd.Categorical(df['occupation']).codes
    df['gender_enc']     = (df['gender'] == 'Male').astype(int)

    print(f"    NPA rate: {df['is_default'].mean()*100:.1f}%")
    return df

# ─────────────────────────────────────────────────────────────
# STEP 4 — PREPARE X, y
# ─────────────────────────────────────────────────────────────
FEATURES = [
    'dti_ratio', 'lti_ratio', 'repayment_pct', 'credit_score_drop',
    'collateral_flag', 'overdue_ratio', 'interest_rate', 'tenure_months',
    'age', 'monthly_income', 'credit_score', 'loan_type_enc',
    'occupation_enc', 'gender_enc'
]

def prepare_data(df):
    print("\n[3/10] Preparing features and target...")
    X = df[FEATURES].fillna(0)
    y = df['is_default']
    print(f"    Features: {len(FEATURES)} | Class 0: {(y==0).sum()} | Class 1: {(y==1).sum()}")
    return X, y, df

# ─────────────────────────────────────────────────────────────
# STEP 5 — TRAIN TEST SPLIT
# ─────────────────────────────────────────────────────────────
def split_data(X, y):
    print("\n[4/10] Train/Test split (80/20)...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y)
    print(f"    Train: {len(X_train)} | Test: {len(X_test)}")
    return X_train, X_test, y_train, y_test

# ─────────────────────────────────────────────────────────────
# STEP 6 — BUILD MODELS WITH SMOTE
# ─────────────────────────────────────────────────────────────
def build_models():
    print("\n[5/10] Building model pipelines (with SMOTE)...")
    smote = SMOTE(random_state=42)
    models = {
        'Logistic Regression': ImbPipeline([
            ('smote', smote),
            ('scaler', StandardScaler()),
            ('model', LogisticRegression(max_iter=1000, random_state=42))
        ]),
        'Random Forest': ImbPipeline([
            ('smote', smote),
            ('model', RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1))
        ]),
        'XGBoost': ImbPipeline([
            ('smote', smote),
            ('model', XGBClassifier(n_estimators=100, random_state=42,
                                     eval_metric='logloss', verbosity=0))
        ])
    }
    return models

# ─────────────────────────────────────────────────────────────
# STEP 7 — TRAIN AND EVALUATE
# ─────────────────────────────────────────────────────────────
def train_evaluate(models, X_train, X_test, y_train, y_test):
    print("\n[6/10] Training and evaluating models...")
    results = {}
    for name, pipeline in models.items():
        print(f"\n    Training {name}...")
        pipeline.fit(X_train, y_train)
        y_pred  = pipeline.predict(X_test)
        y_proba = pipeline.predict_proba(X_test)[:, 1]
        auc_roc = roc_auc_score(y_test, y_proba)
        auc_pr  = average_precision_score(y_test, y_proba)
        results[name] = {
            'pipeline': pipeline,
            'auc_roc':  auc_roc,
            'auc_pr':   auc_pr,
            'y_proba':  y_proba,
            'y_pred':   y_pred
        }
        print(f"    {name} → AUC-ROC: {auc_roc:.4f} | AUC-PR: {auc_pr:.4f}")
        print(classification_report(y_test, y_pred, target_names=['No Default','Default']))
    return results

# ─────────────────────────────────────────────────────────────
# STEP 8 — SELECT BEST MODEL
# ─────────────────────────────────────────────────────────────
def select_best_model(results):
    print("\n[7/10] Selecting best model by AUC-ROC...")
    best_name = max(results, key=lambda k: results[k]['auc_roc'])
    best      = results[best_name]
    print(f"    Best model: {best_name} (AUC-ROC: {best['auc_roc']:.4f})")
    return best_name, best['pipeline']

# ─────────────────────────────────────────────────────────────
# STEP 9 — GENERATE PREDICTIONS + RISK TIERS
# ─────────────────────────────────────────────────────────────
def generate_predictions(best_pipeline, df, X):
    print("\n[8/10] Generating predictions for all loans...")
    proba = best_pipeline.predict_proba(X)[:, 1]
    df = df.copy()
    df['default_probability'] = np.round(proba, 4)
    df['risk_tier'] = pd.cut(
        df['default_probability'],
        bins=[0, 0.2, 0.4, 0.6, 0.8, 1.0],
        labels=['Very Low', 'Low', 'Medium', 'High', 'Critical']
    ).astype(str)
    dist = df['risk_tier'].value_counts()
    print("    Risk tier distribution:")
    for tier, count in dist.items():
        print(f"      {tier}: {count}")
    return df

# ─────────────────────────────────────────────────────────────
# STEP 10 — SAVE TO MYSQL + SAVE MODEL
# ─────────────────────────────────────────────────────────────
def save_results(df, best_pipeline, best_name, engine):
    print("\n[9/10] Saving predictions to MySQL...")

    # Create table if not exists
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS ml_loan_predictions (
                loan_id              INT PRIMARY KEY,
                customer_id          INT,
                default_probability  DECIMAL(6,4),
                risk_tier            VARCHAR(20),
                predicted_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """))
        conn.commit()

    # Save predictions
    pred_df = df[['loan_id', 'customer_id', 'default_probability', 'risk_tier']].copy()
    pred_df.to_sql('ml_loan_predictions', engine,
                   if_exists='replace', index=False, method='multi', chunksize=500)
    print(f"    Saved {len(pred_df)} predictions to ml_loan_predictions table")

    # Save model
    os.makedirs('saved_models', exist_ok=True)
    model_name = best_name.lower().replace(' ', '_')
    path = f"saved_models/loan_default_{model_name}.pkl"
    joblib.dump(best_pipeline, path)
    print(f"\n[10/10] Model saved → {path}")

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("  LOAN DEFAULT (NPA) PREDICTOR — Banking Analytics")
    print("=" * 60)

    engine       = get_engine()
    df           = load_data(engine)
    df           = engineer_features(df)
    X, y, df     = prepare_data(df)
    X_train, X_test, y_train, y_test = split_data(X, y)
    models       = build_models()
    results      = train_evaluate(models, X_train, X_test, y_train, y_test)
    best_name, best_pipeline = select_best_model(results)
    df           = generate_predictions(best_pipeline, df, X)
    save_results(df, best_pipeline, best_name, engine)

    print("\n" + "=" * 60)
    print("  DONE! ml_loan_predictions table created in MySQL")
    print("  Load this table in Power BI for Page 4")
    print("=" * 60)

if __name__ == '__main__':
    main()
