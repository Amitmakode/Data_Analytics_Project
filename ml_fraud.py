# ============================================================
# ML FRAUD TRANSACTION DETECTOR
# Banking Analytics Project — Phase 5
# ============================================================
# Step 1: Install libraries (same as loan predictor)
# Step 2: Update DB_CONFIG with your MySQL credentials
# Step 3: Run: python ml_fraud_detector.py
# ============================================================

import pandas as pd
import numpy as np
import warnings
import os
warnings.filterwarnings('ignore')

from sqlalchemy import create_engine, text
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (classification_report, roc_auc_score,
                             average_precision_score)
from xgboost import XGBClassifier
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline as ImbPipeline
import joblib

# ─────────────────────────────────────────────────────────────
# STEP 1 — DB CONFIG (update these)
# ─────────────────────────────────────────────────────────────
DB_CONFIG = {
    'host': 'localhost',
    'port': 3306,
    'user': 'root',
    'password': '12345',
    'database': 'banking_analytics1'
}

def get_engine():
    url = (f"mysql+pymysql://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
           f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
    return create_engine(url)

# ─────────────────────────────────────────────
# LOAD DATA
# ─────────────────────────────────────────────
def load_data(engine):
    print("\n[1/10] Loading data from MySQL...")
    query = """
        SELECT
            t.transaction_id,
            t.account_id,
            t.amount,
            t.transaction_type,
            t.transaction_mode,
            t.transaction_date,
            t.transaction_time,
            t.is_fraud,
            t.status,
            a.account_type,
            a.balance,
            a.opening_date,
            c.age,
            c.monthly_income,
            c.credit_score,
            c.occupation
        FROM transactions t
        JOIN accounts a  ON t.account_id  = a.account_id
        JOIN customers c ON a.customer_id = c.customer_id
    """
    df = pd.read_sql(query, engine)
    print(f"    Loaded {len(df)} transactions")
    return df

# ─────────────────────────────────────────────
# FEATURE ENGINEERING 
# ─────────────────────────────────────────────
def engineer_features(df):
    print("\n[2/10] Engineering features...")

    # Date
    df['transaction_date'] = pd.to_datetime(df['transaction_date'])

    # 🔥 FIXED TIME HANDLING
    if pd.api.types.is_timedelta64_dtype(df['transaction_time']):
        df['hour'] = (df['transaction_time'].dt.total_seconds() // 3600).astype(int)

    elif pd.api.types.is_datetime64_any_dtype(df['transaction_time']):
        df['hour'] = df['transaction_time'].dt.hour

    else:
        df['transaction_time'] = pd.to_datetime(df['transaction_time'], errors='coerce')
        df['hour'] = df['transaction_time'].dt.hour

    # Time features
    df['is_night']   = ((df['hour'] >= 22) | (df['hour'] <= 5)).astype(int)
    df['is_weekend'] = (df['transaction_date'].dt.dayofweek >= 5).astype(int)

    # Amount features
    df['log_amount'] = np.log1p(df['amount'])
    df['amount_to_balance_ratio'] = df['amount'] / df['balance'].clip(lower=1)

    # Account age
    df['opening_date'] = pd.to_datetime(df['opening_date'])
    df['account_age_days'] = (
        df['transaction_date'] - df['opening_date']
    ).dt.days.clip(lower=0)

    df['new_acct_large_txn'] = (
        (df['account_age_days'] < 90) &
        (df['amount'] > 50000)
    ).astype(int)

    # Encoding
    df['txn_type_enc']  = (df['transaction_type'] == 'Debit').astype(int)
    df['txn_mode_enc']  = pd.Categorical(df['transaction_mode']).codes
    df['acct_type_enc'] = pd.Categorical(df['account_type']).codes
    df['occ_enc']       = pd.Categorical(df['occupation']).codes
    df['status_enc']    = (df['status'] == 'Success').astype(int)

    df['is_fraud'] = df['is_fraud'].astype(int)

    print(f"    Fraud rate: {df['is_fraud'].mean()*100:.2f}%")
    return df

# ─────────────────────────────────────────────
# FEATURES
# ─────────────────────────────────────────────
FEATURES = [
    'log_amount', 'is_night', 'is_weekend', 'amount_to_balance_ratio',
    'new_acct_large_txn', 'txn_type_enc', 'txn_mode_enc', 'acct_type_enc',
    'account_age_days', 'hour', 'age', 'monthly_income', 'credit_score',
    'occ_enc', 'status_enc'
]

def prepare_data(df):
    print("\n[3/10] Preparing data...")
    X = df[FEATURES].fillna(0)
    y = df['is_fraud']
    return X, y, df

# ─────────────────────────────────────────────
# SPLIT
# ─────────────────────────────────────────────
def split_data(X, y):
    print("\n[4/10] Train/Test split...")
    return train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

# ─────────────────────────────────────────────
# MODELS
# ─────────────────────────────────────────────
def build_models():
    print("\n[5/10] Building models...")
    smote = SMOTE(random_state=42)

    return {
        'Logistic Regression': ImbPipeline([
            ('smote', smote),
            ('scaler', StandardScaler()),
            ('model', LogisticRegression(max_iter=1000))
        ]),

        'Random Forest': ImbPipeline([
            ('smote', smote),
            ('model', RandomForestClassifier(n_estimators=100))
        ]),

        'XGBoost': ImbPipeline([
            ('smote', smote),
            ('model', XGBClassifier(
                n_estimators=100,
                eval_metric='logloss',
                verbosity=0,
                scale_pos_weight=10
            ))
        ])
    }

# ─────────────────────────────────────────────
# TRAIN
# ─────────────────────────────────────────────
def train_evaluate(models, X_train, X_test, y_train, y_test):
    print("\n[6/10] Training models...")

    results = {}

    for name, model in models.items():
        print(f"\nTraining {name}...")
        model.fit(X_train, y_train)

        y_proba = model.predict_proba(X_test)[:, 1]

        results[name] = {
            'pipeline': model,
            'auc_pr': average_precision_score(y_test, y_proba)
        }

        print(f"AUC-PR: {results[name]['auc_pr']:.4f}")

    return results

# ─────────────────────────────────────────────
# BEST MODEL
# ─────────────────────────────────────────────
def select_best_model(results):
    print("\n[7/10] Selecting best model...")
    best_name = max(results, key=lambda k: results[k]['auc_pr'])
    return best_name, results[best_name]['pipeline']

# ─────────────────────────────────────────────
# PREDICTIONS
# ─────────────────────────────────────────────
def generate_predictions(model, df, X):
    print("\n[8/10] Generating predictions...")

    proba = model.predict_proba(X)[:, 1]

    df['fraud_probability'] = proba
    df['fraud_confidence'] = pd.cut(
        proba,
        bins=[0, .2, .4, .6, .8, 1],
        labels=['Very Low','Low','Medium','High','Very High']
    )

    return df

# ─────────────────────────────────────────────
# SAVE
# ─────────────────────────────────────────────
def save_results(df, model, name, engine):
    print("\n[9/10] Saving results...")

    df[['transaction_id','fraud_probability','fraud_confidence']].to_sql(
        'ml_fraud_predictions',
        engine,
        if_exists='replace',
        index=False
    )

    os.makedirs('saved_models', exist_ok=True)
    joblib.dump(model, f"saved_models/{name}.pkl")

# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
def main():
    print("="*60)

    engine = get_engine()
    df = load_data(engine)

    # DEBUG (important)
    print("\nDEBUG:")
    print(df['transaction_time'].dtype)

    df = engineer_features(df)
    X, y, df = prepare_data(df)

    X_train, X_test, y_train, y_test = split_data(X, y)

    models = build_models()
    results = train_evaluate(models, X_train, X_test, y_train, y_test)

    best_name, best_model = select_best_model(results)

    df = generate_predictions(best_model, df, X)

    save_results(df, best_model, best_name, engine)

    print("\nDONE!")

if __name__ == '__main__':
    main()